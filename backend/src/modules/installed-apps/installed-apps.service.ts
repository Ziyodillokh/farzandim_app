import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { StorageService } from '../../common/storage/storage.service';
import { AuditService } from '../../common/audit/audit.service';
import { BUCKETS } from '../../common/storage/storage.constants';
import { BatchUpsertAppsDto, InstalledAppDto } from './dto/batch-upsert-apps.dto';

// 96x96 PNG ikona odatda 5–30 KB, lekin murakkab (adaptiv/gradient)
// ikonalar 50 KB dan oshib, jimgina rad etilardi → ota-onada ikona
// ko'rinmасди. Chegarani 256 KB ga oshirdik (baribir kichik, xavfsiz).
const MAX_ICON_SIZE_BYTES = 256 * 1024; // 256 KB
const ICON_SIGNED_URL_TTL = 3600; // 1 hour

function decodeIconBase64(raw: string): { buffer: Buffer; mime: string } | null {
  try {
    let data = raw;
    let mime = 'image/png';
    if (raw.startsWith('data:')) {
      const m = /^data:([^;]+);base64,(.+)$/.exec(raw);
      if (!m) return null;
      mime = m[1];
      data = m[2];
    }
    const buffer = Buffer.from(data, 'base64');
    return { buffer, mime };
  } catch {
    return null;
  }
}

function sanitizePackageKey(packageName: string): string {
  return packageName.replace(/[^a-zA-Z0-9._-]/g, '_').slice(0, 200);
}

@Injectable()
export class InstalledAppsService {
  private readonly logger = new Logger(InstalledAppsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
    private readonly audit: AuditService,
  ) {}

  private async validateChildAccess(childId: string, userId: string) {
    const child = await this.prisma.child.findUnique({
      where: { id: childId },
    });
    if (!child) throw new NotFoundException('Child not found');
    if (child.parentId !== userId && child.childUserId !== userId) {
      throw new ForbiddenException('Forbidden');
    }
    return child;
  }

  async batchUpsert(
    childId: string,
    userId: string,
    dto: BatchUpsertAppsDto,
    request?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    await this.validateChildAccess(childId, userId);

    const now = new Date();
    let iconsUploaded = 0;
    let iconsRejected = 0;

    // Upload icons in parallel
    const iconUploads = await Promise.allSettled(
      dto.apps.map(async (app: InstalledAppDto) => {
        if (!app.iconBase64)
          return { packageName: app.packageName, iconPath: app.iconPath };

        const decoded = decodeIconBase64(app.iconBase64);
        if (!decoded) {
          iconsRejected++;
          return { packageName: app.packageName, iconPath: app.iconPath };
        }
        if (decoded.buffer.length > MAX_ICON_SIZE_BYTES) {
          iconsRejected++;
          this.logger.warn(
            `Icon too large for ${app.packageName}: ${decoded.buffer.length} bytes`,
          );
          return { packageName: app.packageName, iconPath: app.iconPath };
        }
        if (decoded.mime !== 'image/png') {
          iconsRejected++;
          this.logger.warn(
            `Icon mime not png for ${app.packageName}: ${decoded.mime}`,
          );
          return { packageName: app.packageName, iconPath: app.iconPath };
        }

        const key = `icons/${childId}/${sanitizePackageKey(app.packageName)}.png`;
        try {
          await this.storage.upload(BUCKETS.appIcons, key, decoded.buffer, 'image/png');
          iconsUploaded++;
          return { packageName: app.packageName, iconPath: key };
        } catch (err) {
          iconsRejected++;
          this.logger.error(`Icon MinIO upload failed for ${key}`, err);
          return { packageName: app.packageName, iconPath: app.iconPath };
        }
      }),
    );

    const iconPathByPkg = new Map<string, string | undefined>();
    for (const r of iconUploads) {
      if (r.status === 'fulfilled') {
        iconPathByPkg.set(r.value.packageName, r.value.iconPath);
      }
    }

    const ops = dto.apps.map((app: InstalledAppDto) => {
      const iconPath = iconPathByPkg.get(app.packageName) ?? app.iconPath;
      return this.prisma.installedApp.upsert({
        where: {
          childId_packageName: { childId, packageName: app.packageName },
        },
        update: {
          appName: app.appName,
          versionName: app.versionName,
          versionCode: app.versionCode,
          installSource: app.installSource,
          iconPath,
          isSystem: app.isSystem,
          lastSeenAt: now,
        },
        create: {
          childId,
          packageName: app.packageName,
          appName: app.appName,
          versionName: app.versionName,
          versionCode: app.versionCode,
          installSource: app.installSource,
          iconPath,
          isSystem: app.isSystem,
        },
      });
    });

    await this.prisma.$transaction(ops);

    await this.audit.log(
      userId,
      'installed_app',
      'BATCH_UPSERT',
      childId,
      { count: dto.apps.length, iconsUploaded, iconsRejected },
      request,
    );

    return {
      ok: true,
      upserted: dto.apps.length,
      iconsUploaded,
      iconsRejected,
    };
  }

  async list(childId: string, userId: string, includeSystem: boolean) {
    await this.validateChildAccess(childId, userId);

    const apps = await this.prisma.installedApp.findMany({
      where: { childId, ...(includeSystem ? {} : { isSystem: false }) },
      orderBy: { appName: 'asc' },
    });

    const withIconUrls = await Promise.all(
      apps.map(async (app) => {
        let iconUrl: string | null = null;
        if (app.iconPath) {
          try {
            iconUrl = await this.storage.getSignedUrl(
              BUCKETS.appIcons,
              app.iconPath,
              ICON_SIGNED_URL_TTL,
            );
          } catch (err) {
            this.logger.warn(`iconUrl presign failed for ${app.iconPath}`, err);
          }
        }
        return { ...app, iconUrl };
      }),
    );

    return { apps: withIconUrls, count: withIconUrls.length };
  }

  /**
   * Ilova ikonasi baytlarini proxy uchun qaytaradi (auth'siz). Telefon
   * signed MinIO URL'ga ulanolmasligi sababli — backend ichidan o'qiymiz.
   */
  async getIconObject(childId: string, packageName: string) {
    const app = await this.prisma.installedApp.findUnique({
      where: { childId_packageName: { childId, packageName } },
      select: { iconPath: true },
    });
    if (!app?.iconPath) {
      throw new NotFoundException('No icon');
    }
    try {
      return await this.storage.getObject(BUCKETS.appIcons, app.iconPath);
    } catch {
      // Obyekt MinIO'da yo'q — 500 emas, toza 404 (UI fallback ko'rsatadi).
      throw new NotFoundException('Icon object not found');
    }
  }
}
