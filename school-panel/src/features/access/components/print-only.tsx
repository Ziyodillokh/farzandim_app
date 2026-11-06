'use client';

import { type ReactNode, useEffect } from 'react';
import { createPortal } from 'react-dom';

const BODY_FLAG = 'data-print-card';

/**
 * Chop etiladigan karta (kirish ma'lumotlari, taklif kodi). `active` bo'lganda `body`ga portal sifatida qo'shiladi,
 * brauzer chop etish oynasi ochiladi va chop etishda FAQAT shu blok qoladi (`globals.css`: `body[data-print-card]`).
 * Oyna yopilganda (`afterprint`) `onDone`. Karta mazmuni (parol!) URL, storage yoki keshga YOZILMAYDI — faqat shu DOM tuguni.
 * Hech qachon ekranda ko'rinmaydi (`print-only`).
 */
export function PrintOnly({ active, onDone, children }: { active: boolean; onDone: () => void; children: ReactNode }) {
  useEffect(() => {
    if (!active) return;
    document.body.setAttribute(BODY_FLAG, '');
    const finish = () => onDone();
    window.addEventListener('afterprint', finish, { once: true });
    const frame = window.requestAnimationFrame(() => window.print());
    return () => {
      window.cancelAnimationFrame(frame);
      window.removeEventListener('afterprint', finish);
      document.body.removeAttribute(BODY_FLAG);
    };
  }, [active, onDone]);

  if (!active) return null;
  return createPortal(
    <div data-print-card-root="" className="print-only">
      {children}
    </div>,
    document.body,
  );
}
