import type { NotificationItem } from '@/data/contracts';

/** «Ulanish so'rovlari» sahifasi (LINK_REVIEW / LINK_CORRECTION). */
export const LINK_REQUESTS_HREF = '/students/link-requests';

/** Panel ichidagi yo'l (`/…`), tashqi yoki protokolsiz (`//host`) manzil emas. */
export function isPanelPath(href: string | null | undefined): href is string {
  return typeof href === 'string' && href.startsWith('/') && !href.startsWith('//');
}

/**
 * Bildirishnoma bosilganda ochiladigan sahifa. Kirish (5-bosqich) turlari backend `href` bermasa ham tegishli sahifaga olib boradi:
 * ulanish tekshiruvi/tuzatish — «Ulanish so'rovlari»; parol tiklash — o'quvchi (params'da id yo'q, shuning uchun ism bo'yicha qidiruv).
 * Qolgan turlar o'zgarishsiz (`href` yoki hech narsa).
 */
export function notificationHref(item: Pick<NotificationItem, 'kind' | 'href' | 'params'>): string | null {
  switch (item.kind) {
    case 'LINK_REVIEW':
    case 'LINK_CORRECTION':
      return isPanelPath(item.href) ? item.href : LINK_REQUESTS_HREF;
    case 'CHILD_RECOVERY_REQUEST': {
      if (isPanelPath(item.href)) return item.href;
      const name = String(item.params.studentName ?? '').trim();
      return name ? `/students?search=${encodeURIComponent(name)}` : '/students';
    }
    default:
      return item.href;
  }
}
