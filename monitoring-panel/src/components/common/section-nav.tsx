'use client';

import { useEffect, useRef, useState } from 'react';

import { cn } from '@/lib/utils';

export type SectionNavItem = { id: string; label: string };

/** Yopishqoq panel ostidagi chiziq: bo'lim tepasi shu chiziqdan o'tganda "joriy" bo'ladi. */
const OBSERVER_MARGIN = '-120px 0px -55% 0px';
/** Bosilgan bo'lim silliq aylantirish tugaguncha tanlangan bo'lib turadi. */
const CLICK_LOCK_MS = 1200;
/** Bir qatordagi (yonma-yon) bo'limlar — tepasi shu farq ichida. */
const SAME_ROW_PX = 4;

/**
 * Sahifa ichidagi bo'limlarga tez o'tish (yopishqoq "pill" panel). Joriy bo'lim
 * ajratiladi; bosilganda bo'limga fokus o'tadi (klaviatura va ekran o'quvchilar
 * uchun), "kamroq harakat" sozlamasida aylantirish silliq emas.
 */
export function SectionNav({ items, label, className }: { items: readonly SectionNavItem[]; label: string; className?: string }) {
  const [active, setActive] = useState<string>(items[0]?.id ?? '');
  const lockUntil = useRef(0);
  const lastClicked = useRef<string | null>(null);

  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        if (Date.now() < lockUntil.current) return;
        const visible = entries.filter((e) => e.isIntersecting).sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top);
        const first = visible[0];
        if (!first) return;
        // Yonma-yon bo'limlar (bir qatorda) — oxirgi bosilgani ustun.
        const sameRow = visible.filter((e) => Math.abs(e.boundingClientRect.top - first.boundingClientRect.top) <= SAME_ROW_PX);
        const preferred = sameRow.find((e) => e.target.id === lastClicked.current) ?? first;
        setActive(preferred.target.id);
      },
      { rootMargin: OBSERVER_MARGIN },
    );
    for (const item of items) {
      const el = document.getElementById(item.id);
      if (el) observer.observe(el);
    }
    return () => observer.disconnect();
  }, [items]);

  const go = (id: string) => {
    const el = document.getElementById(id);
    if (!el) return;
    lockUntil.current = Date.now() + CLICK_LOCK_MS;
    lastClicked.current = id;
    setActive(id);
    const reduceMotion = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches ?? false;
    el.scrollIntoView({ behavior: reduceMotion ? 'auto' : 'smooth', block: 'start' });
    if (!el.hasAttribute('tabindex')) el.setAttribute('tabindex', '-1');
    el.focus({ preventScroll: true });
  };

  return (
    <nav aria-label={label} className={cn('sticky top-[76px] z-20 -mx-1 mb-5 overflow-x-auto px-1 no-print', className)}>
      <div className="glass-bar inline-flex min-w-max gap-1 rounded-2xl p-1">
        {items.map((item) => (
          <a
            key={item.id}
            href={`#${item.id}`}
            aria-current={active === item.id ? 'true' : undefined}
            onClick={(e) => {
              e.preventDefault();
              go(item.id);
            }}
            className={cn(
              'h-8 rounded-xl px-3 text-[0.78rem] font-semibold leading-8 outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring',
              active === item.id ? 'bg-primary text-primary-foreground shadow-soft' : 'text-muted-foreground hover:text-foreground',
            )}
          >
            {item.label}
          </a>
        ))}
      </div>
    </nav>
  );
}
