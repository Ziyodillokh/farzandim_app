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
  accessibilityEnabled: true,
  screenTimePermission: true,
} satisfies Prisma.ChildSelect;

export type DeviceChild = Prisma.ChildGetPayload<{ select: typeof deviceChildSelect }>;

/**
 * - bola ilovasi bog'lanmagan: telefoni yo'q → NO_PHONE, bor → NO_PERMISSION
 *   (oila hali ruxsat bermagan);
 * - ulangan, lekin cheklov ruxsati o'chiq (Android Accessibility / iOS Ekran
 *   vaqti) → NO_PERMISSION; uzoq jim → OFFLINE; aks holda APPLIED.
 */
export function deviceStateOf(
  student: { id: string; device: SchoolDeviceOs },
  child: DeviceChild | null,
  now = new Date(),
): DeviceStateView {
  const lastSeenAt = child?.lastSeenAt?.toISOString() ?? null;
  const state = (status: DeviceModeStatus): DeviceStateView => ({ studentId: student.id, status, lastSeenAt });
  if (!child) return state(student.device === 'NONE' ? 'NO_PHONE' : 'NO_PERMISSION');
  if (!child.pairedAt || child.accessibilityEnabled === false || child.screenTimePermission === false) {
    return state('NO_PERMISSION');
  }
  const silentFor = child.lastSeenAt ? now.getTime() - child.lastSeenAt.getTime() : Infinity;
  return state(silentFor > DEVICE_OFFLINE_AFTER_MS ? 'OFFLINE' : 'APPLIED');
}
