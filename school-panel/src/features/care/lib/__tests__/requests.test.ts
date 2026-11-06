import { describe, expect, it } from 'vitest';

import { newChildMessages } from '../requests';

describe('newChildMessages', () => {
  it('ochilmagan murojaat: bolaning birinchi xabari «yangi xabar» hisoblanmaydi', () => {
    expect(newChildMessages({ openedAt: null, unreadFromChild: 1 })).toBe(0);
    expect(newChildMessages({ openedAt: null, unreadFromChild: 0 })).toBe(0);
  });

  it('ochilmagan, lekin bola yana yozgan: qo\'shimcha xabarlar soni', () => {
    expect(newChildMessages({ openedAt: null, unreadFromChild: 3 })).toBe(2);
  });

  it('ochilgan murojaat: o\'qilmagan xabarlarning hammasi', () => {
    expect(newChildMessages({ openedAt: '2026-11-06T09:00:00', unreadFromChild: 1 })).toBe(1);
    expect(newChildMessages({ openedAt: '2026-11-06T09:00:00', unreadFromChild: 0 })).toBe(0);
  });
});
