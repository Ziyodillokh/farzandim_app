'use client';

import { type ReactNode, useEffect } from 'react';
import { createPortal } from 'react-dom';

/**
 * Chop etiladigan karta (kirish ma'lumotlari, taklif kodi). `job` > 0 bo'lganda `body`ga portal sifatida qo'shiladi,
 * brauzer chop etish oynasi ochiladi va chop etishda FAQAT shu blok qoladi (`globals.css`: `body[data-print-card]`).
 * Har bosishda `job` oshadi — oldingi chop etish tugamagan bo'lsa ham qayta chop etiladi.
 *
 * Karta chop etish oynasi yopilgach, sahifadagi KEYINGI bosish yoki tugma bosilishida (`onDone`) DOM'dan olinadi. `afterprint`
 * ataylab ishlatilmaydi: Chrome uni ko'rib chiqish oynasi hali ochiq turganda yuborishi mumkin, sozlama o'zgarganda ko'rinish
 * jonli DOM'dan qayta quriladi — karta erta olib tashlansa u bo'sh chiqadi. Modal oyna ochiq turganda sahifa hodisa olmaydi,
 * shuning uchun «keyingi hodisa» = oyna yopilgan. Karta mazmuni (parol!) URL, storage yoki keshga YOZILMAYDI — faqat shu DOM tuguni.
 * Hech qachon ekranda ko'rinmaydi (`print-only`).
 */
export function PrintOnly({ job, onDone, children }: { job: number; onDone: () => void; children: ReactNode }) {
  useEffect(() => {
    if (job === 0) return;
    document.body.setAttribute('data-print-card', '');
    const frame = window.requestAnimationFrame(() => window.print());
    const finish = () => onDone();
    // Tugmani bosib turish (takroriy `keydown`) chop etishni tugatmasin.
    const onKey = (event: KeyboardEvent) => {
      if (!event.repeat) finish();
    };
    window.addEventListener('pointerdown', finish, { once: true, capture: true });
    window.addEventListener('keydown', onKey, { capture: true });
    return () => {
      window.cancelAnimationFrame(frame);
      window.removeEventListener('pointerdown', finish, { capture: true });
      window.removeEventListener('keydown', onKey, { capture: true });
      document.body.removeAttribute('data-print-card');
    };
    // `job` har bosishda o'zgaradi — effekt qayta ishga tushib, yana chop etadi.
  }, [job, onDone]);

  if (job === 0) return null;
  return createPortal(
    <div data-print-card-root="" className="print-only">
      {children}
    </div>,
    document.body,
  );
}
