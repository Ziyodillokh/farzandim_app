// Kirish (K1) e2e yordamchilari: ota-ona orqali kirish maʼlumotlarini berish, bola logini (har so'rov uchun
// yangi IP — 30/10daq limit testlarni to'smasin), WebSocket hodisalarini ushlash, soat.

import { JwtService } from '@nestjs/jwt';
import type { SchoolStaffRole } from '@prisma/client';
import { SCHOOL_ROLES } from '../../src/school/auth/permissions';
import { ChildAuthClock } from '../../src/modules/child-auth/child-auth-clock';
import { RealtimeGateway } from '../../src/common/realtime/realtime.gateway';
import { createChild, createParent, TestChild, TestParent } from './factories';
import { TestApp } from './test-app';

type Method = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';

/** Bolaning o'z (doimiy) paroli: siyosatdan o'tadi. */
export const OWN_PASSWORD = 'Kitob2026';

export interface DeviceBody {
  id: string;
  model?: string;
  platform: 'android' | 'ios';
  /** `false` — qurilma boshqa bolaning nazoratini yuritadi: yangi sessiya ASOSIY bo'lmaydi (yuborilmasa standart true). */
  hostsControl?: boolean;
}

export const device = (
  id = 'install-1',
  platform: 'android' | 'ios' = 'android',
  model = 'Redmi Note 12S',
  hostsControl?: boolean,
): DeviceBody => ({
  id,
  model,
  platform,
  ...(hostsControl !== undefined && { hostsControl }),
});

let ipSeq = 0;
/** Har chaqiruvda yangi IP: IP limiti (30/10daq) faqat uni maxsus sinaydigan testlarda ishlaydi. */
export const freshIp = () => `10.${Math.floor(ipSeq / 250) % 250}.${(ipSeq += 1) % 250}.7`;

export function api(t: TestApp, method: Method, url: string, opts: { token?: string; payload?: object; ip?: string } = {}) {
  return t.app.inject({
    method,
    url: `/api${url}`,
    remoteAddress: opts.ip ?? freshIp(),
    headers: opts.token ? { authorization: `Bearer ${opts.token}` } : {},
    ...(opts.payload && { payload: opts.payload }),
  });
}

export interface IssuedCredential {
  login: string;
  temporaryPassword: string;
  issuedAt: string;
  /** `issuedAt` + 14 kun: shundan keyin vaqtinchalik parol TEMP_PASSWORD_EXPIRED beradi. */
  temporaryPasswordExpiresAt: string;
}

/** Vaqtinchalik parol amal qilish muddati (kun) — kontrakt. */
export const TEMP_PASSWORD_TTL_DAYS = 14;
export const DAY_MS = 24 * 60 * 60 * 1000;

/** Ota-ona bolaga kirish maʼlumotlarini beradi (yoki qayta tiklaydi). */
export async function issueAsParent(
  t: TestApp,
  parent: TestParent,
  childId: string,
  body: object = {},
): Promise<IssuedCredential> {
  const res = await api(t, 'POST', `/children/${childId}/credentials`, { token: parent.token, payload: body });
  if (res.statusCode !== 201) throw new Error(`issue ${res.statusCode}: ${res.body}`);
  return res.json();
}

export const childLogin = (t: TestApp, login: string, password: string, dev: DeviceBody = device(), ip?: string) =>
  api(t, 'POST', '/auth/child-login', { payload: { login, password, device: dev }, ip });

export interface ChildSession {
  accessToken: string;
  refreshToken: string;
  sessionId: string;
  userId: string;
}

/** Vaqtinchalik parol -> setup -> o'z paroli bilan OK. */
export async function loginThroughSetup(
  t: TestApp,
  cred: IssuedCredential,
  dev: DeviceBody = device(),
  newPassword = OWN_PASSWORD,
): Promise<ChildSession> {
  const first = await childLogin(t, cred.login, cred.temporaryPassword, dev);
  if (first.statusCode !== 200 || first.json().status !== 'SETUP_REQUIRED') throw new Error(`login ${first.statusCode}: ${first.body}`);
  const setup = await api(t, 'POST', '/auth/child-setup', {
    payload: { setupToken: first.json().setupToken, newPassword, device: dev },
  });
  if (setup.statusCode !== 200) throw new Error(`setup ${setup.statusCode}: ${setup.body}`);
  return sessionOf(setup.json());
}

/** Parol o'rnatilgan credential bilan oddiy kirish. */
export async function loginPlain(
  t: TestApp,
  login: string,
  dev: DeviceBody = device(),
  password = OWN_PASSWORD,
): Promise<ChildSession> {
  const res = await childLogin(t, login, password, dev);
  if (res.statusCode !== 200 || res.json().status !== 'OK') throw new Error(`login ${res.statusCode}: ${res.body}`);
  return sessionOf(res.json());
}

const sessionOf = (body: { accessToken: string; refreshToken: string; sessionId: string; user: { id: string } }): ChildSession => ({
  accessToken: body.accessToken,
  refreshToken: body.refreshToken,
  sessionId: body.sessionId,
  userId: body.user.id,
});

/** Yangi ota-ona + (juftlangan) bola. */
export async function familyOf(t: TestApp, childName = 'Aziza Karimova'): Promise<{ parent: TestParent; child: TestChild }> {
  const parent = await createParent(t.prisma);
  const child = await createChild(t.prisma, parent, { name: childName });
  return { parent, child };
}

// ─── WebSocket va soat ──────────────────────────────────────────────

export interface RealtimeEvent {
  userId: string;
  event: string;
  payload: Record<string, unknown>;
}

/** `emitToUser` chaqiruvlarini yig'adi (haqiqiy WebSocket'ga yuborilmaydi). */
export function captureRealtime(t: TestApp) {
  const events: RealtimeEvent[] = [];
  jest.spyOn(t.app.get(RealtimeGateway), 'emitToUser').mockImplementation((userId, event, payload) => {
    events.push({ userId, event, payload: payload as Record<string, unknown> });
  });
  return {
    events,
    of: (userId: string, event: string) => events.filter((e) => e.userId === userId && e.event === event),
    clear: () => events.splice(0, events.length),
  };
}

/** Bola kirishi soatini boshqaradi; qaytgan funksiya vaqtni suradi. */
export function controlClock(t: TestApp, start: Date = new Date()) {
  let now = start;
  t.app.get(ChildAuthClock).now = () => new Date(now.getTime());
  return {
    advance: (ms: number) => {
      now = new Date(now.getTime() + ms);
    },
    set: (date: Date) => {
      now = date;
    },
    now: () => now,
  };
}

/** Vaqtni haqiqiy soatga qaytaradi (keyingi testlarga ta'sir qilmasin). */
export function restoreClock(t: TestApp): void {
  t.app.get(ChildAuthClock).now = () => new Date();
}

/** Eski (sid'siz) juftlangan qurilma yangilash tokeni — oila kodi / QR bilan ulangan bola ilovasi shunday token oladi. */
export function legacyRefreshToken(userId: string, tokenVersion = 0): string {
  return new JwtService({}).sign(
    { userId, role: 'CHILD', tokenVersion },
    {
      secret: process.env.JWT_REFRESH_SECRET,
      audience: 'farzandim-consumer',
      issuer: 'farzandim-backend',
      expiresIn: '1h',
    },
  );
}

export const decode = (t: TestApp, token: string) => t.app.get(JwtService).decode(token) as Record<string, unknown>;

/** Mavjud bo'lmasa: JSON matn sifatida butun ma'lumotlar bazasini qidiradi (parol hech qayerda saqlanmaganini isbotlash). */
export async function dbContains(t: TestApp, needle: string): Promise<string[]> {
  const tables = await t.prisma.$queryRaw<{ tablename: string }[]>`
    SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename <> '_prisma_migrations'`;
  const hits: string[] = [];
  for (const { tablename } of tables) {
    const rows = await t.prisma.$queryRawUnsafe<{ hit: boolean }[]>(
      `SELECT EXISTS (SELECT 1 FROM "${tablename}" x WHERE x::text LIKE $1) AS hit`,
      `%${needle}%`,
    );
    if (rows[0]?.hit) hits.push(tablename);
  }
  return hits;
}

/**
 * Maktab rollari jadvaliga testda vaqtincha ruxsat qo'shadi / olib tashlaydi (ilova va test bitta jarayonda, shuning
 * uchun guard va oluvchilarni aniqlash ham yangi jadvalni ko'radi). Qaytgan funksiya jadvalni tiklaydi.
 */
export function patchRolePermissions(role: SchoolStaffRole, change: { add?: string[]; remove?: string[] }): () => void {
  const definition = SCHOOL_ROLES[role] as unknown as { permissions: string[] };
  const original = definition.permissions;
  definition.permissions = [...original.filter((p) => !(change.remove ?? []).includes(p)), ...(change.add ?? [])];
  return () => {
    definition.permissions = original;
  };
}
