import type { NotificationItem } from '@/data/contracts';

/** «Ulanish so'rovlari» sahifasi (LINK_REVIEW / LINK_CORRECTION). */
export const LINK_REQUESTS_HREF = '/students/link-requests';

/** `/` bilan boshlanadi; `//host`, `/\host` (brauzer `\` ni `/` deb o'qiydi) va boshqaruv belgilari (tab, yangi qator) yo'q. */
const PANEL_PATH = /^\/(?![/\\])[^\\\u0000-\u001f]*$/;

/** Panel ichidagi yo'l (`/…`): tashqi, protokolli yoki protokolsiz (`//host`) manzil emas. */
export function isPanelPath(href: string | null | undefined): href is string {
  return typeof href === 'string' && PANEL_PATH.test(href);
}

/**
 * Bildirishnoma bosilganda ochiladigan sahifa. Kirish (5-bosqich) turlari backend `href` bermasa ham tegishli sahifaga olib boradi:
 * ulanish tekshiruvi/tuzatish — «Ulanish so'rovlari»; parol tiklash — o'quvchi (params'da id yo'q, shuning uchun ism bo'yicha qidiruv).
 * Qolgan turlar: `href` faqat panel ichidagi yo'l bo'lsa (backend javobi ishonchsiz kirish sifatida tekshiriladi), aks holda hech narsa.
 */
export function notificationHref(item: Pick<NotificationItem, 'kind' | 'href' | 'params'>): string | null {
  switch (item.kind) {
    case 'LINK_REVIEW':
    case 'LINK_CORRECTION':
    case 'GUARDIAN_REVIEW':
      return isPanelPath(item.href) ? item.href : LINK_REQUESTS_HREF;
    case 'CHILD_RECOVERY_REQUEST': {
      if (isPanelPath(item.href)) return item.href;
      const name = String(item.params.studentName ?? '').trim();
      return name ? `/students?search=${encodeURIComponent(name)}` : '/students';
    }
    default:
      return isPanelPath(item.href) ? item.href : null;
  }
}
