import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';

const SINGLETON_ID = 'singleton';
const CACHE_TTL_MS = 15_000;

export interface SecuritySettings {
  ipAllowlistEnabled: boolean;
  ipAllowlist: string[];
}

/**
 * Admin xavfsizlik sozlamalari (singleton) — IP allowlist saqlash, enforcement
 * va kichik in-memory kesh. Guard har so'rovda `isIpAllowed` chaqiradi, shu
 * sabab DB'ga har safar bormaslik uchun keshlaymiz (15s TTL).
 */
@Injectable()
export class SecuritySettingsService {
  constructor(private readonly prisma: PrismaService) {}

  private cache: { data: SecuritySettings; at: number } | null = null;

  private normalizeIp(ip: string): string {
    return ip.replace(/^::ffff:/, '').trim();
  }

  async getSettings(): Promise<SecuritySettings> {
    const now = Date.now();
    if (this.cache && now - this.cache.at < CACHE_TTL_MS) {
      return this.cache.data;
    }
    // findUnique + create-if-missing — upsert(update:{}) har o'qishda @updatedAt
    // tufayli keraksiz yozuv qilardi.
    let row = await this.prisma.adminSecuritySettings.findUnique({
      where: { id: SINGLETON_ID },
    });
    row ??= await this.prisma.adminSecuritySettings.create({
      data: { id: SINGLETON_ID },
    });
    const data: SecuritySettings = {
      ipAllowlistEnabled: row.ipAllowlistEnabled,
      ipAllowlist: row.ipAllowlist,
    };
    this.cache = { data, at: now };
    return data;
  }

  /** Enforcement: yoqilgan bo'lsa → FAQAT ro'yxatdagi IP ruxsat. Yoqilgan
   *  holatda bo'sh ro'yxat bo'lmaydi (update() buni rad etadi), shu sabab
   *  bu yerda "bo'sh → hammaga ruxsat" bypass YO'Q (xavfsizlik). */
  async isIpAllowed(ip: string): Promise<boolean> {
    const s = await this.getSettings();
    if (!s.ipAllowlistEnabled) return true;
    return s.ipAllowlist.includes(this.normalizeIp(ip));
  }

  async update(
    dto: { ipAllowlistEnabled?: boolean; ipAllowlist?: string[] },
    requesterIp: string,
  ): Promise<SecuritySettings> {
    const current = await this.getSettings();
    const nextEnabled = dto.ipAllowlistEnabled ?? current.ipAllowlistEnabled;
    const nextList = (dto.ipAllowlist ?? current.ipAllowlist)
      .map((ip) => this.normalizeIp(ip))
      .filter((ip) => ip.length > 0);

    // Enforcement yoqilayotgan bo'lsa: (1) ro'yxat bo'sh bo'lmasligi shart
    // (aks holda hamma bloklanadi yoki bypass yuzaga keladi); (2) so'rovchining
    // IP'si ro'yxatda bo'lishi shart (admin o'zini bloklab qo'ymasligi uchun).
    if (nextEnabled) {
      if (nextList.length === 0) {
        throw new BadRequestException(
          "IP cheklashni yoqish uchun kamida bitta IP qo'shing",
        );
      }
      const me = this.normalizeIp(requesterIp);
      if (!nextList.includes(me)) {
        throw new BadRequestException(
          `O'zingizni bloklab qo'ymaslik uchun avval joriy IP'ingizni (${me}) ro'yxatga qo'shing`,
        );
      }
    }

    const row = await this.prisma.adminSecuritySettings.upsert({
      where: { id: SINGLETON_ID },
      create: {
        id: SINGLETON_ID,
        ipAllowlistEnabled: nextEnabled,
        ipAllowlist: nextList,
      },
      update: { ipAllowlistEnabled: nextEnabled, ipAllowlist: nextList },
    });

    this.cache = null; // keshni bekor qilamiz — enforcement darhol kuchga kiradi
    return {
      ipAllowlistEnabled: row.ipAllowlistEnabled,
      ipAllowlist: row.ipAllowlist,
    };
  }
}
