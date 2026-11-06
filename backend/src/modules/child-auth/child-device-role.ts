// Bolaning qurilma roli: ASOSIY (MAIN) — ota-ona nazorati shu qurilmada ishlaydi (D2); boshqalari QO'SHIMCHA
// (SECONDARY) — faqat akkauntga kirish. Rol sessiya ochilganda BIR MARTA belgilanadi va o'zgarmaydi.
//
// Bolada hozirgi asosiy qurilma bor, agar:
//   (a) bola foydalanuvchisi faol va eski juftlash (oila kodi / QR) bilan yaratilgan (`User.createdVia = NULL`):
//       sid'siz juftlangan qurilma asosiy; yoki
//   (b) yopilmagan LOGIN sessiyasi asosiy deb belgilangan (`UserSession.isMain`).
// Aks holda yangi sessiya ASOSIY bo'ladi. Asosiy sessiya yopilsa rol bo'shaydi; sessiyalarni chiqaradigan
// tiklash (`signOutDevices`) juftlangan qurilmani ham asosiylikdan chiqaradi (`createdVia = 'RECOVERED'`).

export const DEVICE_ROLES = ['MAIN', 'SECONDARY'] as const;
export type DeviceRole = (typeof DEVICE_ROLES)[number];

/** `User.createdVia`: login/parol bilan yaratilgan bola foydalanuvchisi. */
export const CREATED_VIA_LOGIN = 'LOGIN';
/** `User.createdVia`: eski juftlash foydalanuvchisi, juftlangan qurilma tiklashda chiqarilgan. */
export const CREATED_VIA_RECOVERED = 'RECOVERED';

/** Eski juftlash (oila kodi / QR) bilan yaratilgan foydalanuvchimi (eski qatorlarda `createdVia` NULL). */
export const isLegacyPairedUser = (user: { createdVia: string | null }): boolean => user.createdVia === null;

export function decideDeviceRole(current: { legacyPairedMain: boolean; activeLoginMain: boolean }): DeviceRole {
  return current.legacyPairedMain || current.activeLoginMain ? 'SECONDARY' : 'MAIN';
}
