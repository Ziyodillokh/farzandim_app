import { describe, expect, it } from 'vitest';

import type { NotificationItem } from '@/data/contracts';
import { isPanelPath, LINK_REQUESTS_HREF, notificationHref } from '../href';

const item = (kind: NotificationItem['kind'], href: string | null, params: NotificationItem['params'] = {}) => ({ kind, href, params });

describe('isPanelPath', () => {
  it('faqat panel ichidagi yo\'l', () => {
    expect(isPanelPath('/students/view?id=1')).toBe(true);
    expect(isPanelPath('//evil.example/x')).toBe(false);
    expect(isPanelPath('https://evil.example/x')).toBe(false);
    expect(isPanelPath('javascript:alert(1)')).toBe(false);
    expect(isPanelPath('')).toBe(false);
    expect(isPanelPath(null)).toBe(false);
    expect(isPanelPath(undefined)).toBe(false);
  });
});

describe('notificationHref: kirish turlari', () => {
  it('LINK_REVIEW va LINK_CORRECTION — backend href bermasa ham «Ulanish so\'rovlari»', () => {
    expect(notificationHref(item('LINK_REVIEW', null))).toBe(LINK_REQUESTS_HREF);
    expect(notificationHref(item('LINK_CORRECTION', null))).toBe('/students/link-requests');
  });

  it('backend panel ichidagi href bersa — o\'sha; begona manzil (tashqi, //host) e\'tiborsiz', () => {
    expect(notificationHref(item('LINK_REVIEW', '/students/link-requests'))).toBe('/students/link-requests');
    expect(notificationHref(item('LINK_REVIEW', 'https://evil.example/'))).toBe(LINK_REQUESTS_HREF);
    expect(notificationHref(item('LINK_CORRECTION', '//evil.example/'))).toBe(LINK_REQUESTS_HREF);
    expect(notificationHref(item('CHILD_RECOVERY_REQUEST', '/students/view?id=stu-1&tab=access'))).toBe('/students/view?id=stu-1&tab=access');
  });

  it('CHILD_RECOVERY_REQUEST — href yo\'q bo\'lsa ism bo\'yicha qidiruv (params\'da o\'quvchi id\'si yo\'q)', () => {
    expect(notificationHref(item('CHILD_RECOVERY_REQUEST', null, { studentName: 'Karimova Aziza', className: '7-A' }))).toBe('/students?search=Karimova%20Aziza');
    expect(notificationHref(item('CHILD_RECOVERY_REQUEST', null, { studentName: "O'tkirov Ali & Co", className: '7-A' }))).toBe("/students?search=O'tkirov%20Ali%20%26%20Co");
    expect(notificationHref(item('CHILD_RECOVERY_REQUEST', 'https://evil.example/', { studentName: '  ' }))).toBe('/students');
  });
});

describe('notificationHref: boshqa turlar o\'zgarishsiz', () => {
  it('href — qanday kelgan bo\'lsa shunday (yoki null)', () => {
    expect(notificationHref(item('EARLY_EXIT_PENDING', '/attendance/early-exit'))).toBe('/attendance/early-exit');
    expect(notificationHref(item('SAFETY_SIGNAL', null))).toBeNull();
    expect(notificationHref(item('DATA_DELETION_REQUEST', null, { studentName: 'x' }))).toBeNull();
  });
});
