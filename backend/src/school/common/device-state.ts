// O'quvchi telefonining School Mode holati (panel `DeviceState`) — ota-ona
// bog'lagan Parvoz bola ilovasining (`Child`) ruxsat va aloqa ma'lumotidan.
// Foydalanish statistikasi o'qilmaydi: faqat ruxsat bor-yo'qligi va oxirgi aloqa.

import { Prisma, SchoolDeviceOs } from '@prisma/client';

export type DeviceModeStatus = 'APPLIED' | 'NO_PERMISSION' | 'NO_PHONE' | 'OFFLINE';

export interface DeviceStateView {
  studentId: string;
  status: DeviceModeStatus;
  lastSeenAt: string | null;
}

/** Bola qurilmasi shu muddatdan ko'p jim bo'lsa — "oflayn" (iOS fonda kam yozadi). */
export const DEVICE_OFFLINE_AFTER_MS = 30 * 60_000;

export const deviceChildSelect = {
  pairedAt: true,
  lastSeenAt: true,
  androidVersion: true,
  usagePermission: true,
  overlayPermission: true,
  screenTimePermission: true,
} satisfies Prisma.ChildSelect;

export type DeviceChild = Prisma.ChildGetPayload<{ select: typeof deviceChildSelect }>;

/**
 * Cheklov ruxsati o'chiqmi — platformaga qarab:
 * - Android (`androidVersion` "Android …"): «Foydalanish ma'lumotlari» (ilovani
 *   aniqlash) yoki «Boshqa ilovalar ustidan ko'rsatish» (blok ekrani). Maxsus
 *   imkoniyatlar (Accessibility) 2026-08 dan ishlatilmaydi — endi shart emas;
 * - iOS: «Ekran vaqti» (Family Controls).
 * `null` — noma'lum (eski ilova yubormagan): ruxsat yo'q deb hisoblanmaydi.
 */
function permissionMissing(child: DeviceChild): boolean {
  // Bola ilovasi OS versiyasini shu maydonda yuboradi: "Android 14" yoki "iOS 17.5".
  if (child.androidVersion?.toLowerCase().startsWith('android')) {
    return child.usagePermission === false || child.overlayPermission === false;
  }
  return child.screenTimePermission === false;
}

/**
 * - bola ilovasi bog'lanmagan: telefoni yo'q → NO_PHONE, bor → NO_PERMISSION
 *   (oila hali ruxsat bermagan);
 * - ulangan, lekin cheklov ruxsati o'chiq (`permissionMissing`) → NO_PERMISSION;
 *   uzoq jim → OFFLINE; aks holda APPLIED.
 */
export function deviceStateOf(
  student: { id: string; device: SchoolDeviceOs },
  child: DeviceChild | null,
  now = new Date(),
): DeviceStateView {
  const lastSeenAt = child?.lastSeenAt?.toISOString() ?? null;
  const state = (status: DeviceModeStatus): DeviceStateView => ({ studentId: student.id, status, lastSeenAt });
  if (!child) return state(student.device === 'NONE' ? 'NO_PHONE' : 'NO_PERMISSION');
  if (!child.pairedAt || permissionMissing(child)) return state('NO_PERMISSION');
  const silentFor = child.lastSeenAt ? now.getTime() - child.lastSeenAt.getTime() : Infinity;
  return state(silentFor > DEVICE_OFFLINE_AFTER_MS ? 'OFFLINE' : 'APPLIED');
}
