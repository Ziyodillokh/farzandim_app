import {
  Injectable,
  InternalServerErrorException,
  Logger,
} from '@nestjs/common';
import { readFileSync } from 'fs';
import { join } from 'path';
import { PrismaService } from '../../common/database/prisma.service';

type PlatformInfo = {
  latest: string;
  minSupported: string;
  playStoreUrl?: string;
  appStoreUrl?: string;
  directApkUrl?: string;
};

type AppVersionEntry = {
  android: PlatformInfo;
  ios: PlatformInfo;
  releaseNotes: string;
  isForceUpdate: boolean;
};

type AppVersionsConfig = {
  parent: AppVersionEntry;
  child: AppVersionEntry;
};

const CONFIG_PATH = join(process.cwd(), 'config', 'app-versions.json');

@Injectable()
export class AppVersionService {
  private readonly logger = new Logger(AppVersionService.name);

  constructor(private readonly prisma: PrismaService) {}

  private readConfig(): AppVersionsConfig {
    const raw = readFileSync(CONFIG_PATH, 'utf-8');
    return JSON.parse(raw) as AppVersionsConfig;
  }

  /**
   * Manifest — fayl ASOS, baza esa `latest` ni USTIDAN yozadi.
   *
   * Fayl havolalar, `minSupported`, `releaseNotes` va `isForceUpdate` ni
   * beradi (bular qo'lda boshqariladi). `latest` esa
   * `StoreVersionSyncService` kuniga bir marta do'konning O'ZIDAN o'qib
   * bazaga yozadi — qo'lda yangilash unutilib, foydalanuvchiga yangi
   * reliz haqida aytilmay qolmasin (iOS 1.0.1 bilan aynan shunday bo'ldi).
   *
   * Baza bo'sh yoki o'qilmasa — fayldagi qiymat ishlatiladi, ya'ni eski
   * xulq. Bu yerda hech qachon xato tashlamaymiz: versiya endpointi
   * yiqilsa ilova yangilanishni umuman tekshira olmaydi.
   */
  async getVersion(app: 'parent' | 'child'): Promise<AppVersionEntry> {
    let entry: AppVersionEntry;
    try {
      const config = this.readConfig();
      const found = config[app];
      if (!found) {
        throw new InternalServerErrorException(`Config entry missing: ${app}`);
      }
      entry = found;
    } catch (err) {
      if (err instanceof InternalServerErrorException) throw err;
      this.logger.error('app-version: config read failed', err);
      throw new InternalServerErrorException('Configuration unavailable');
    }

    try {
      const rows = await this.prisma.storeVersion.findMany({ where: { app } });
      if (rows.length === 0) return entry;

      const android = rows.find((r) => r.platform === 'android');
      const ios = rows.find((r) => r.platform === 'ios');
      return {
        ...entry,
        android: android
          ? { ...entry.android, latest: android.latest }
          : entry.android,
        ios: ios ? { ...entry.ios, latest: ios.latest } : entry.ios,
      };
    } catch (err) {
      // Baza javob bermasa fayldagi qiymat bilan davom etamiz.
      this.logger.warn('app-version: store override o\'qilmadi', err);
      return entry;
    }
  }
}
