import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as https from 'node:https';
import { EnvConfig } from '../config/env.schema';

const ESKIZ_HOST = 'notify.eskiz.uz';
const ESKIZ_API_PREFIX = '/api';

export interface SmsResult {
  sent: boolean;
  error?: string;
}

interface HttpReply {
  status: number;
  body: string;
}

/**
 * Eskiz'ga `node:https` orqali POST — global `fetch` (undici) `notify.eskiz.uz`
 * bilan `ECONNRESET` beradi (TLS handshake'ni server reset qiladi), `https`
 * moduli esa tizim OpenSSL'idan foydalanadi va curl kabi muvaffaqiyatli
 * ulanadi. Shuning uchun barcha Eskiz chaqiruvlari shu helper orqali ketadi.
 */
function eskizPost(
  path: string,
  form: URLSearchParams,
  token?: string,
): Promise<HttpReply> {
  return new Promise<HttpReply>((resolve, reject) => {
    const body = form.toString();
    const req = https.request(
      {
        hostname: ESKIZ_HOST,
        port: 443,
        path: `${ESKIZ_API_PREFIX}${path}`,
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Content-Length': Buffer.byteLength(body),
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        timeout: 15_000,
      },
      (res) => {
        let data = '';
        res.setEncoding('utf8');
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () =>
          resolve({ status: res.statusCode ?? 0, body: data }),
        );
      },
    );
    req.on('error', reject);
    req.on('timeout', () => req.destroy(new Error('Eskiz request timeout')));
    req.write(body);
    req.end();
  });
}

@Injectable()
export class SmsService {
  private readonly logger = new Logger(SmsService.name);
  private cachedToken: string | null = null;

  constructor(private readonly config: ConfigService<EnvConfig, true>) {}

  /**
   * Whether Eskiz SMS credentials are configured.
   */
  isSmsConfigured(): boolean {
    const email = this.config.get('ESKIZ_EMAIL', { infer: true });
    const password = this.config.get('ESKIZ_PASSWORD', { infer: true });
    return Boolean(email && password);
  }

  private async login(): Promise<string> {
    const form = new URLSearchParams();
    form.set('email', this.config.get('ESKIZ_EMAIL', { infer: true }) ?? '');
    form.set(
      'password',
      this.config.get('ESKIZ_PASSWORD', { infer: true }) ?? '',
    );

    const res = await eskizPost('/auth/login', form);

    if (res.status < 200 || res.status >= 300) {
      throw new Error(`Eskiz login failed: ${res.status} ${res.body}`);
    }

    const json = JSON.parse(res.body) as { data?: { token?: string } };
    const token = json.data?.token;
    if (!token) throw new Error('Eskiz login: token not returned');
    return token;
  }

  private async getToken(): Promise<string> {
    if (this.cachedToken) return this.cachedToken;
    this.cachedToken = await this.login();
    return this.cachedToken;
  }

  /* ------------------------------------------------------------------ */
  /*  Eskiz tasdiqlangan shablonlar (panel:my.eskiz.uz/sms/settings)    */
  /* ------------------------------------------------------------------ */
  // Har bir matn AYNAN shu shaklda yuborilishi shart — Eskiz strict
  // template check qiladi, mos kelmasa "message is not in template"
  // xato qaytaradi. Kod matn oxiridagi raqam o'rniga qo'yiladi.
  //
  // Tasdiqlangan shablon ID'lari (my.eskiz.uz, "Tasdiqlangan", sender 4546):
  //   81885 — login, 81886 — register, 81887 — parol tiklash.
  // Brend "Farzandim Edu" → "Parvoz" ga o'zgartirildi (2026-07-15 yangilangan
  // shablonlar). Matnni o'zgartirsangiz Eskiz panelida ham yangi shablon
  // tasdiqlanishi SHART, aks holda SMS yuborilmaydi.

  /** ID 81887 — parolni tiklash flow uchun (61 belgi). */
  async sendResetCode(phone: string, code: string): Promise<SmsResult> {
    return this.sendSms(
      phone,
      `Parvoz ilovasida parolni tiklash uchun tasdiqlash kodi: ${code}`,
    );
  }

  /** ID 81886 — ro'yxatdan o'tish (register) flow uchun (63 belgi). */
  async sendRegisterCode(phone: string, code: string): Promise<SmsResult> {
    return this.sendSms(
      phone,
      `Parvoz ilovasiga ro'yxatdan o'tish uchun tasdiqlash kodi: ${code}`,
    );
  }

  /** ID 81885 — login flow uchun (52 belgi). */
  async sendLoginCode(phone: string, code: string): Promise<SmsResult> {
    return this.sendSms(
      phone,
      `Parvoz ilovasiga kirish uchun tasdiqlash kodi: ${code}`,
    );
  }

  /**
   * Send an SMS message via Eskiz.uz.
   * Auto-refreshes the auth token on 401.
   *
   * Tasdiqlangan shablonlar bilan ishlash uchun yuqoridagi `sendLoginCode`
   * / `sendRegisterCode` / `sendResetCode` metodlardan foydalaning.
   */
  async sendSms(phone: string, message: string): Promise<SmsResult> {
    if (!this.isSmsConfigured()) {
      return { sent: false, error: 'SMS provider not configured' };
    }

    const mobilePhone = phone.replace(/\D/g, '');
    const from = this.config.get('ESKIZ_FROM', { infer: true });

    const attempt = (token: string): Promise<HttpReply> => {
      const form = new URLSearchParams();
      form.set('mobile_phone', mobilePhone);
      form.set('message', message);
      form.set('from', from);
      return eskizPost('/message/sms/send', form, token);
    };

    try {
      let res = await attempt(await this.getToken());

      // Token expired - re-login and retry once
      if (res.status === 401) {
        this.cachedToken = null;
        res = await attempt(await this.getToken());
      }

      // Eskiz javobini tahlil qilamiz — 200 status'da ham `status: error`
      // bo'lishi mumkin (template approved emas, balans yo'q, va h.k.).
      // Bularni o'tkazib yubormaslik uchun body'ni o'qiymiz.
      const text = res.body;
      let body: { status?: string; message?: string; id?: string } = {};
      try {
        body = JSON.parse(text) as typeof body;
      } catch {/* JSON emas — text qoldiramiz */}

      const resOk = res.status >= 200 && res.status < 300;
      if (!resOk) {
        this.logger.error(
          { phone: mobilePhone, status: res.status, body: text },
          'Eskiz SMS HTTP xato',
        );
        return {
          sent: false,
          error: `Eskiz HTTP ${res.status}: ${body.message ?? text}`,
        };
      }

      // 200 javob, lekin Eskiz "status:error" qaytarishi mumkin.
      // Yoki sms ID yo'q bo'lsa — yuborilmagan.
      if (body.status === 'error' || (!body.id && body.status !== 'waiting')) {
        this.logger.error(
          { phone: mobilePhone, body: text },
          'Eskiz SMS muvaffaqiyatsiz (200 lekin error)',
        );
        return {
          sent: false,
          error: `Eskiz: ${body.message ?? 'unknown error'} (templates approved'mi?)`,
        };
      }

      this.logger.log(
        { phone: mobilePhone, smsId: body.id, status: body.status },
        'Eskiz SMS yuborildi',
      );
      return { sent: true };
    } catch (err) {
      this.logger.error({ err }, 'SMS sending exception');
      return {
        sent: false,
        error: err instanceof Error ? err.message : 'SMS sending error',
      };
    }
  }
}
