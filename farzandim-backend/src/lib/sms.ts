// SMS yuborish — Eskiz.uz provayderi (Sprint 6 — P1).
//
// Kalitlar (.env: ESKIZ_EMAIL/ESKIZ_PASSWORD) yo'q bo'lsa SMS o'chiq turadi —
// isSmsConfigured() false qaytaradi (FCM/payments bilan bir xil graceful-disable).
// Eskiz token ~30 kun amal qiladi: xotirada cache qilinadi, 401'da qayta login.
//
// Hujjat: https://documenter.getpostman.com/view/663428/RzfmES4z

import { env } from '../config/env';

const ESKIZ_BASE = 'https://notify.eskiz.uz/api';

let cachedToken: string | null = null;

/** .env'da Eskiz kalitlari bor-yo'qligi. false bo'lsa SMS o'chiq. */
export function isSmsConfigured(): boolean {
  return Boolean(env.ESKIZ_EMAIL && env.ESKIZ_PASSWORD);
}

async function login(): Promise<string> {
  const form = new URLSearchParams();
  form.set('email', env.ESKIZ_EMAIL ?? '');
  form.set('password', env.ESKIZ_PASSWORD ?? '');
  const res = await fetch(`${ESKIZ_BASE}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: form.toString(),
  });
  if (!res.ok) throw new Error(`Eskiz login failed: ${res.status}`);
  const json = (await res.json()) as { data?: { token?: string } };
  const token = json.data?.token;
  if (!token) throw new Error("Eskiz login: token qaytmadi");
  return token;
}

async function getToken(): Promise<string> {
  if (cachedToken) return cachedToken;
  cachedToken = await login();
  return cachedToken;
}

export interface SmsResult {
  sent: boolean;
  error?: string;
}

/**
 * Telefon raqamga SMS yuboradi.
 * @param phone +998XXXXXXXXX yoki 998XXXXXXXXX — raqam bo'lmagan belgilar olib tashlanadi.
 */
export async function sendSms(phone: string, message: string): Promise<SmsResult> {
  if (!isSmsConfigured()) {
    return { sent: false, error: "SMS provayderi sozlanmagan" };
  }
  const mobilePhone = phone.replace(/\D/g, ''); // 998XXXXXXXXX

  async function attempt(token: string): Promise<Response> {
    const form = new URLSearchParams();
    form.set('mobile_phone', mobilePhone);
    form.set('message', message);
    form.set('from', env.ESKIZ_FROM);
    return fetch(`${ESKIZ_BASE}/message/sms/send`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        Authorization: `Bearer ${token}`,
      },
      body: form.toString(),
    });
  }

  try {
    let res = await attempt(await getToken());
    // Token muddati tugagan bo'lsa — qayta login qilib bir marta urinamiz.
    if (res.status === 401) {
      cachedToken = null;
      res = await attempt(await getToken());
    }
    if (!res.ok) {
      return { sent: false, error: `Eskiz send failed: ${res.status}` };
    }
    return { sent: true };
  } catch (err) {
    return {
      sent: false,
      error: err instanceof Error ? err.message : 'SMS yuborishda xato',
    };
  }
}
