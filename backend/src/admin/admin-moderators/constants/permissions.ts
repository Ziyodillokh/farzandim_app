export const ALL_ADMIN_PERMISSIONS = [
  // Users
  'view_users',
  'manage_users',
  'block_users',
  'warn_users',
  'edit_user_data',

  // Moderators
  'manage_moderators',

  // Content
  'view_content',
  'manage_content',
  'edit_content',
  'approve_content',
  'reject_content',
  'delete_content',
  'upload_audiobooks',
  'edit_audiobooks',
  'delete_audiobooks',
  'approve_audiobooks',

  // Monetization
  'manage_monetization',
  'view_payments',

  // Notifications
  'send_notifications',
  'manage_notifications',

  // Olympiads / Contests
  'manage_olympiads',
  'create_contest',
  'edit_contest',
  'delete_contest',
  'select_winner',

  // Analytics & Audit
  'view_analytics',
  'view_audit_log',
] as const;

export type AdminPermission = (typeof ALL_ADMIN_PERMISSIONS)[number];

export const ROLE_PRESETS: Record<string, readonly string[]> = {
  super_admin: [], // full access — bypass check
  finance: [
    'view_users',
    'manage_monetization',
    'view_payments',
    'view_analytics',
  ],
  content_maker: [
    'view_content',
    'manage_content',
    'edit_content',
    'approve_content',
    'reject_content',
    'delete_content',
    'upload_audiobooks',
    'edit_audiobooks',
    'delete_audiobooks',
    'approve_audiobooks',
  ],
  support: [
    'view_users',
    'block_users',
    'warn_users',
    'edit_user_data',
    'view_content',
    'send_notifications',
  ],
  custom: [],
};

/**
 * Filter out unknown permissions from an input array.
 */
export function sanitizePermissions(input: string[]): string[] {
  const allowed = new Set<string>(ALL_ADMIN_PERMISSIONS);
  return input.filter((p) => allowed.has(p));
}
