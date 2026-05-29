/**
 * Canonical admin permission keys. Must stay aligned with the Flutter Web
 * admin panel: `admin_panel/lib/features/moderators/staff_permissions.dart`.
 */

export const ALL_ADMIN_PERMISSIONS = [
  'view_users',
  'block_users',
  'warn_users',
  'edit_user_data',
  'view_content',
  'approve_content',
  'reject_content',
  'edit_content',
  'delete_content',
  'upload_audiobooks',
  'edit_audiobooks',
  'delete_audiobooks',
  'approve_audiobooks',
  'create_contest',
  'edit_contest',
  'delete_contest',
  'select_winner',
  'send_notifications',
  'view_analytics',
  'manage_monetization',
  'view_payments',
] as const;

export type AdminPermission = (typeof ALL_ADMIN_PERMISSIONS)[number];

const PERMISSION_SET = new Set<string>(ALL_ADMIN_PERMISSIONS);

export const ADMIN_ROLE_PRESETS: Record<string, readonly string[]> = {
  super_admin: ALL_ADMIN_PERMISSIONS,
  finance: ['view_payments', 'manage_monetization', 'view_analytics'],
  content_maker: [
    'view_content',
    'approve_content',
    'reject_content',
    'edit_content',
    'delete_content',
    'upload_audiobooks',
    'edit_audiobooks',
    'delete_audiobooks',
    'approve_audiobooks',
  ],
  support: ['view_users', 'warn_users', 'view_content', 'send_notifications'],
  custom: [],
};

export function sanitizePermissions(input: unknown): string[] {
  if (!Array.isArray(input)) return [];
  const seen = new Set<string>();
  for (const item of input) {
    if (typeof item !== 'string') continue;
    if (PERMISSION_SET.has(item)) seen.add(item);
  }
  return Array.from(seen).sort();
}
