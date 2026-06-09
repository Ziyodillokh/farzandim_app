import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { EnvConfig } from '../config/env.schema';

const ESKIZ_BASE = 'https://notify.eskiz.uz/api';

export interface SmsResult {
  sent: boolean;
  error?: string;
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

    const res = await fetch(`${ESKIZ_BASE}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: form.toString(),
    });

    if (!res.ok) throw new Error(`Eskiz login failed: ${res.status}`);

    const json = (await res.json()) as { data?: { token?: string } };
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
  // xato qaytaradi. `{code}` faqat raqamga almashtiriladi.

  /** ID 77251 — parolni tiklash flow uchun. */
  async sendResetCode(phone: string, code: string): Promise<SmsResult> {
    return this.sendSms(
      phone,
      `Farzandim Edu ilovasida parolni tiklash uchun tasdiqlash kodi: ${code}`,
    );
  }

  /** ID 77252 — ro'yxatdan o'tish (register) flow uchun. */
  async sendRegisterCode(phone: string, code: string): Promise<SmsResult> {
    return this.sendSms(
      phone,
      `Farzandim Edu ilovasiga ro'yxatdan o'tish uchun tasdiqlash kodi: ${code}`,
    );
  }

  /** ID 77253 — login flow uchun. */
  async sendLoginCode(phone: string, code: string): Promise<SmsResult> {
    return this.sendSms(
      phone,
      `Farzandim Edu ilovasiga kirish uchun tasdiqlash kodi: ${code}`,
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

    const attempt = async (token: string): Promise<Response> => {
      const form = new URLSearchParams();
      form.set('mobile_phone', mobilePhone);
      form.set('message', message);
      form.set('from', from);
      return fetch(`${ESKIZ_BASE}/message/sms/send`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          Authorization: `Bearer ${token}`,
        },
        body: form.toString(),
      });
    };

    try {
      let res = await attempt(await this.getToken());

      // Token expired - re-login and retry once
      if (res.status === 401) {
        this.cachedToken = null;
        res = await attempt(await this.getToken());
      }

      if (!res.ok) {
        return { sent: false, error: `Eskiz send failed: ${res.status}` };
      }
      return { sent: true };
    } catch (err) {
      return {
        sent: false,
        error: err instanceof Error ? err.message : 'SMS sending error',
      };
    }
  }
}
