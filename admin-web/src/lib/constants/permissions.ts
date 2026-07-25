/**
 * Admin RBAC permission catalog — backend admin-permissions bilan mos.
 * Moderator yaratish/tahrirlash formasida ishlatiladi.
 */

export const MODERATOR_ROLES = [
  { value: 'super_admin', label: 'Super Admin' },
  { value: 'finance', label: 'Moliyachi' },
  { value: 'content_maker', label: 'Kontent maker' },
  { value: 'support', label: 'Support' },
  { value: 'custom', label: 'Maxsus (ruxsatlardan tanlangan)' },
] as const;

export interface PermissionGroup {
  group: string;
  permissions: { key: string; label: string }[];
}

export const PERMISSION_GROUPS: PermissionGroup[] = [
  {
    group: 'Foydalanuvchilar boshqaruvi',
    permissions: [
      { key: 'view_users', label: "Foydalanuvchilarni ko'rish" },
      { key: 'block_users', label: 'Foydalanuvchilarni bloklash' },
      { key: 'warn_users', label: 'Ogohlantirish berish' },
      { key: 'edit_user_data', label: "Ma'lumotni tahrirlash" },
    ],
  },
  {
    group: 'Kontent moderatsiyasi',
    permissions: [
      { key: 'view_content', label: "Kontentni ko'rish" },
      { key: 'approve_content', label: 'Kontentni tasdiqlash' },
      { key: 'reject_content', label: 'Kontentni rad etish' },
      { key: 'edit_content', label: 'Kontentni tahrirlash' },
      { key: 'delete_content', label: "Kontentni o'chirish" },
    ],
  },
  {
    group: 'Audiokitoblar',
    permissions: [
      { key: 'upload_audiobooks', label: 'Yuklash' },
      { key: 'edit_audiobooks', label: 'Tahrirlash' },
      { key: 'delete_audiobooks', label: "O'chirish" },
      { key: 'approve_audiobooks', label: 'Tasdiqlash' },
    ],
  },
  {
    group: 'Konkurslar',
    permissions: [
      { key: 'create_contest', label: 'Yaratish' },
      { key: 'edit_contest', label: 'Tahrirlash' },
      { key: 'delete_contest', label: "O'chirish" },
      { key: 'select_winner', label: "G'olibni tanlash" },
    ],
  },
  {
    group: 'Bildirishnomalar',
    permissions: [{ key: 'send_notifications', label: 'Bildirishnoma yuborish' }],
  },
  {
    group: 'Analitika',
    permissions: [{ key: 'view_analytics', label: "Ko'rish" }],
  },
  {
    group: 'Monetizatsiya',
    permissions: [
      { key: 'manage_monetization', label: 'Tarif va promokod boshqaruvi' },
      { key: 'view_payments', label: "To'lovlarni ko'rish" },
    ],
  },
];

export const ALL_PERMISSION_KEYS = PERMISSION_GROUPS.flatMap((g) => g.permissions.map((p) => p.key));

/** Rol → default permission set. */
export const ROLE_PRESETS: Record<string, string[]> = {
  super_admin: ALL_PERMISSION_KEYS,
  finance: ['view_payments', 'manage_monetization', 'view_analytics'],
  content_maker: [
    'view_content', 'approve_content', 'reject_content', 'edit_content', 'delete_content',
    'upload_audiobooks', 'edit_audiobooks', 'delete_audiobooks', 'approve_audiobooks',
  ],
  support: ['view_users', 'warn_users', 'view_content', 'send_notifications'],
  custom: [],
};

export const AGE_OPTIONS = Array.from({ length: 19 }, (_, i) => i); // 0..18
// Tarif — kontentni ko'rish uchun KERAKLI eng past obuna. Backend rank
// bilan ishlaydi (free=0 < standard < premium): tanlangan tarifdan YUQORI
// obunachilar ham ko'radi. Shu sabab `free` = AMALDA "Barchasi" (har qanday
// tarifdagi, hatto obunasi tugagan foydalanuvchi ham ko'radi) — yorlig'i
// "Barchasi" deb aniqroq qilib qo'yildi (qiymat o'zgarmadi: 'free').
export const PLAN_REQUIRED_OPTIONS = [
  { value: 'free', label: 'Barchasi' },
  { value: 'standard', label: 'Standard' },
  { value: 'premium', label: 'Premium' },
];
