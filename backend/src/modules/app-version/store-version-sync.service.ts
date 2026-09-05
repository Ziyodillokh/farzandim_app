import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { readFileSync } from 'fs';
import { join } from 'path';
import { PrismaService } from '../../common/database/prisma.service';
import {
  appStoreIdFromUrl,
  isValidVersion,
  parseAppStoreVersion,
  parsePlayVersion,
  shouldAccept,
} from './store-version.utils';

/**
 * Do'kondagi JONLI versiyani avtomatik aniqlash.
 *
 * MUAMMO (2026-08-26 va 2026-09-05'da ikki marta takrorlandi): `latest`
 * qo'lda yangilanardi. Unutilsa — yangi reliz chiqqani foydalanuvchiga
 * aytilmasdi (iOS 1.0.1 chiqqach manifest 1.0.0 da qolib ketdi).
 * Aksincha, chiqmagan versiya yozilsa — SOXTA "yangilanish bor"
 * bildirishnomasi chiqib, Play'da hech narsa topilmasdi.
 *
 * Yechim: kuniga bir marta do'konning O'ZIDAN so'raymiz.
 *
 * ⚠️ NEGA BAZAGA YOZAMIZ, FAYLGA EMAS: deploy `rsync --delete` bilan
 * repo'dagi backend/ ni serverga ko'chiradi — faylga yozilgan qiymat
 * keyingi deploy'da yo'qoladi.
 *
 * XAVFSIZLIK QOIDALARI (buzilmasin — soxta bildirishnoma qaytmasin):
 *   1. Faqat `x.y` yoki `x.y.z` shaklidagi qiymat qabul qilinadi.
 *   2. Ma'lum qiymatdan PAST versiya hech qachon yozilmaydi.
 *   3. So'rov yiqilsa yoki javob tanilmasa — eski qiymat SAQLANADI,
 *      xato log qilinadi. "Bilmayman" holati "noto'g'ri yozish"dan afzal.
 */
@Injectable()
export class StoreVersionSyncService {
  private readonly logger = new Logger(StoreVersionSyncService.name);

  constructor(private readonly prisma: PrismaService) {}

  private static readonly TIMEOUT_MS = 15_000;

  /** Har kuni 04:30 — kam yuklama vaqti. */
  @Cron('0 30 4 * * *', { name: 'store-version-sync' })
  async syncAll(): Promise<void> {
    for (const app of ['parent', 'child'] as const) {
      const entry = this.manifestEntry(app);
      if (!entry) continue;

      const appStoreUrl = entry.ios?.appStoreUrl;
      if (appStoreUrl) {
        await this.syncOne(app, 'ios', () => this.fetchAppStore(appStoreUrl));
      }
      const playUrl = entry.android?.playStoreUrl;
      if (playUrl) {
        await this.syncOne(app, 'android', () => this.fetchPlay(playUrl));
      }
    }
  }

  /** Bitta (app, platform) juftini yangilaydi — xatolar shu yerda ushlanadi. */
  private async syncOne(
    app: string,
    platform: string,
    fetcher: () => Promise<string | null>,
  ): Promise<void> {
    let found: string | null = null;
    try {
      found = await fetcher();
    } catch (err) {
      this.logger.warn(`${app}/${platform}: do'kondan o'qib bo'lmadi`, err);
      return;
    }

    if (!isValidVersion(found)) {
      this.logger.warn(
        `${app}/${platform}: versiya tanilmadi (${found ?? 'null'}) — eski qiymat qoldi`,
      );
      return;
    }

    const known = await this.prisma.storeVersion.findUnique({
      where: { app_platform: { app, platform } },
    });

    // Pastga tushirmaymiz: do'kon sahifasi vaqtincha noto'g'ri o'qilsa
    // foydalanuvchiga "yangilanish bor" deb ko'rsatilib qolmasin.
    if (!shouldAccept(found, known?.latest)) {
      this.logger.warn(
        `${app}/${platform}: ${found} < ${known?.latest ?? '—'} — ` +
          'e\'tiborsiz qoldirildi (pastga tushirmaymiz)',
      );
      return;
    }
    if (known?.latest === found) return;

    await this.prisma.storeVersion.upsert({
      where: { app_platform: { app, platform } },
      create: {
        app,
        platform,
        latest: found,
        source: platform === 'ios' ? 'itunes' : 'play',
      },
      update: {
        latest: found,
        source: platform === 'ios' ? 'itunes' : 'play',
      },
    });
    this.logger.log(
      `${app}/${platform}: ${known?.latest ?? '—'} → ${found} (do'kondan)`,
    );
  }

  /**
   * App Store — rasmiy iTunes Lookup API (JSON, barqaror).
   * `https://apps.apple.com/app/id6798972223` dan raqamni ajratamiz.
   */
  private async fetchAppStore(appStoreUrl: string): Promise<string | null> {
    const id = appStoreIdFromUrl(appStoreUrl);
    if (!id) return null;
    const res = await this.get(
      `https://itunes.apple.com/lookup?id=${id}&country=uz`,
    );
    return res ? parseAppStoreVersion(res) : null;
  }

  /**
   * Play Market — rasmiy ochiq API yo'q, sahifadan o'qiymiz.
   *
   * ⚠️ Bu MO'RT: Google sahifa tuzilishini istalgan vaqtda o'zgartirishi
   * mumkin. Shuning uchun bir nechta naqsh sinaladi va hech biri mos
   * kelmasa `null` qaytariladi — eski qiymat saqlanib qoladi (soxta
   * yangilanish chiqmaydi). Sinishi log'da ko'rinadi.
   */
  private async fetchPlay(playStoreUrl: string): Promise<string | null> {
    const html = await this.get(`${playStoreUrl}&hl=en&gl=US`);
    if (!html) return null;

    return parsePlayVersion(html);
  }

  /** Timeout bilan matn olish. Xato bo'lsa `null`. */
  private async get(url: string): Promise<string | null> {
    const ctrl = new AbortController();
    const t = setTimeout(
      () => ctrl.abort(),
      StoreVersionSyncService.TIMEOUT_MS,
    );
    try {
      const res = await fetch(url, {
        signal: ctrl.signal,
        headers: { 'User-Agent': 'ParvozVersionSync/1.0' },
      });
      if (!res.ok) return null;
      return await res.text();
    } finally {
      clearTimeout(t);
    }
  }

  /** Havolalarni olish uchun manifestni o'qiydi (yozmaydi). */
  private manifestEntry(app: string): {
    android?: { playStoreUrl?: string };
    ios?: { appStoreUrl?: string };
  } | null {
    try {
      const raw = readFileSync(
        join(process.cwd(), 'config', 'app-versions.json'),
        'utf-8',
      );
      return (JSON.parse(raw) as Record<string, never>)[app] ?? null;
    } catch (err) {
      this.logger.error('manifest o\'qilmadi', err);
      return null;
    }
  }
}
