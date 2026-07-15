import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';
import { EnvConfig } from '../config/env.schema';

export interface MailResult {
  sent: boolean;
  error?: string;
}

/**
 * MailService — nodemailer (SMTP) orqali email yuborish.
 *
 * Asosiy ishlatilishi: ro'yxatdan o'tishda email tasdiqlash kodi (SMS OTP'ning
 * email varianti). SmsService bilan bir xil shaklda — `isMailConfigured()` +
 * `sendRegisterCode(email, code)`.
 *
 * Gmail uchun .env:
 *   SMTP_HOST=smtp.gmail.com
 *   SMTP_PORT=587
 *   SMTP_USER=sizning@gmail.com
 *   SMTP_PASS=<16-belgili App Password>   (oddiy parol EMAS)
 *   MAIL_FROM=Parvoz <sizning@gmail.com>
 *
 * Sozlanmagan bo'lsa: email yuborilmaydi, kod faqat log'ga chiqadi (dev qulay),
 * `sent:false` qaytadi — chaqiruvchi (auth.service) 503 beradi.
 */
@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  private transporter: nodemailer.Transporter | null = null;

  constructor(private readonly config: ConfigService<EnvConfig, true>) {}

  /** SMTP kalitlari (USER + PASS) berilganmi. */
  isMailConfigured(): boolean {
    const user = this.config.get('SMTP_USER', { infer: true });
    const pass = this.config.get('SMTP_PASS', { infer: true });
    return Boolean(user && pass);
  }

  private getTransport(): nodemailer.Transporter {
    if (this.transporter) return this.transporter;
    const host = this.config.get('SMTP_HOST', { infer: true });
    const port = this.config.get('SMTP_PORT', { infer: true });
    this.transporter = nodemailer.createTransport({
      host,
      port,
      // 465 = implicit TLS (secure), 587/25 = STARTTLS (secure:false).
      secure: port === 465,
      auth: {
        user: this.config.get('SMTP_USER', { infer: true }),
        pass: this.config.get('SMTP_PASS', { infer: true }),
      },
    });
    return this.transporter;
  }

  // Brend "Farzandim Edu" → "Parvoz" (2026-07-15). SMS shablonlari bilan bir
  // xil brend — foydalanuvchi SMS'da "Parvoz", email'da boshqa nom ko'rmasin.
  // Email'da Eskiz kabi shablon cheklovi yo'q — matnni erkin o'zgartirsa
  // bo'ladi.

  /** Ro'yxatdan o'tish (register) tasdiqlash kodi. */
  async sendRegisterCode(email: string, code: string): Promise<MailResult> {
    return this.sendCode(
      email,
      code,
      "Parvoz — ro'yxatdan o'tish kodi",
      "Parvoz ilovasiga ro'yxatdan o'tishni yakunlash uchun tasdiqlash kodi",
    );
  }

  /** Parolni tiklash tasdiqlash kodi (kelajakda ishlatish uchun). */
  async sendResetCode(email: string, code: string): Promise<MailResult> {
    return this.sendCode(
      email,
      code,
      'Parvoz — parolni tiklash kodi',
      'Parvoz ilovasida parolni tiklash uchun tasdiqlash kodi',
    );
  }

  /** Email o'zgartirish — yangi manzilni tasdiqlash kodi. */
  async sendVerifyCode(email: string, code: string): Promise<MailResult> {
    return this.sendCode(
      email,
      code,
      'Parvoz — email tasdiqlash kodi',
      'Parvoz ilovasida yangi email manzilingizni tasdiqlash uchun kod',
    );
  }

  /** Umumiy kod yuborish — matn + minimal HTML shabloni. */
  private async sendCode(
    to: string,
    code: string,
    subject: string,
    intro: string,
  ): Promise<MailResult> {
    if (!this.isMailConfigured()) {
      // Dev qulaylik: SMTP yo'q bo'lsa kodni log'ga chiqaramiz (test uchun).
      this.logger.warn(
        `[MAIL sozlanmagan] ${to} uchun kod: ${code} — "${subject}"`,
      );
      return { sent: false, error: 'Mail provider not configured' };
    }

    try {
      await this.getTransport().sendMail({
        from: this.config.get('MAIL_FROM', { infer: true }),
        to,
        subject,
        text: `${intro}: ${code}\n\nKod 10 daqiqa amal qiladi. Agar bu so'rovni siz yubormagan bo'lsangiz, e'tiborsiz qoldiring.`,
        html: this.buildHtml(intro, code),
      });
      this.logger.log({ to }, 'Email kodi yuborildi');
      return { sent: true };
    } catch (err) {
      this.logger.error({ to, err }, 'Email yuborishda xato');
      return {
        sent: false,
        error: err instanceof Error ? err.message : 'Mail sending error',
      };
    }
  }

  private buildHtml(intro: string, code: string): string {
    return `<!doctype html>
<html lang="uz">
  <body style="margin:0;padding:24px;background:#F4F6FC;font-family:Arial,Helvetica,sans-serif;">
    <div style="max-width:480px;margin:0 auto;background:#ffffff;border-radius:16px;padding:32px;border:1px solid #E5EAF3;">
      <div style="font-size:20px;font-weight:700;color:#0B1C30;margin-bottom:8px;">Farzandim&nbsp;Edu</div>
      <div style="font-size:14px;color:#5A6B66;line-height:1.5;margin-bottom:24px;">${intro}:</div>
      <div style="font-size:34px;font-weight:800;letter-spacing:8px;color:#2170E4;text-align:center;padding:16px;background:#EEF3FF;border-radius:12px;">${code}</div>
      <div style="font-size:12px;color:#9AA4B6;line-height:1.5;margin-top:24px;">Kod 10 daqiqa amal qiladi. Agar bu so'rovni siz yubormagan bo'lsangiz, ushbu xatni e'tiborsiz qoldiring.</div>
    </div>
  </body>
</html>`;
  }
}
