'use client';

import { useCallback, useRef } from 'react';

/** Faol tab paneli (`tabindex=0`): asl tugma yo'qolganda fokus shu yerga qaytadi. */
function activeTabPanel(): HTMLElement | null {
  return document.querySelector<HTMLElement>('[role="tabpanel"][data-state="active"]');
}

/**
 * Oyna yopilganda fokusni oynani ochgan tugmaga qaytarish. Radix Dialog fokusni faqat `DialogTrigger` ga qaytaradi;
 * holat orqali ochiladigan oynalarda (bu ilovada hammasi) u `body` ga tushib qoladi — klaviatura va ekran o'qish
 * dasturi foydalanuvchisi joyini yo'qotadi. `remember()` — ochishdan OLDIN (bosish ishlovchisida), `restore` —
 * `onCloseAutoFocus` ga. Tugma DOM'dan olib tashlangan bo'lsa (masalan, qator yo'qolgan) — `fallback` elementi.
 */
export function useFocusReturn(fallback: () => HTMLElement | null = activeTabPanel): {
  remember: () => void;
  restore: (event: Event) => void;
} {
  const origin = useRef<HTMLElement | null>(null);

  const remember = useCallback(() => {
    const active = document.activeElement;
    origin.current = active instanceof HTMLElement && active !== document.body ? active : null;
  }, []);

  const restore = useCallback(
    (event: Event) => {
      event.preventDefault();
      const target = origin.current?.isConnected ? origin.current : fallback();
      origin.current = null;
      target?.focus();
    },
    [fallback],
  );

  return { remember, restore };
}
