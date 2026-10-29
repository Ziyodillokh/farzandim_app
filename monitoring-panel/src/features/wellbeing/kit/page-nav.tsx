'use client';

import { useEffect, useState } from 'react';

import { cn } from '@/lib/utils';

export type PageNavItem = { id: string; label: string };

/** Yopishqoq navbar balandligi — bo'lim tepasi shu chiziqdan pastda ajratiladi. */
const OBSERVER_MARGIN = '-120px 0px -55% 0px';

/**
 * Sahifa ichidagi bo'limlarga tez o'tish (yopishqoq "pill" panel, dashboard
 * bilan bir xil ko'rinish). Joriy bo'lim ajratiladi.
 */
export function PageNav({ items, label }: { items: readonly PageNavItem[]; label: string }) {
  const [active, setActive] = useState<string>(items[0]?.id ?? '');

  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        const visible = entries.filter((e) => e.isIntersecting).sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top)[0];
        if (visible) setActive(visible.target.id);
      },
      { rootMargin: OBSERVER_MARGIN },
    );
    for (const item of items) {
      const el = document.getElementById(item.id);
      if (el) observer.observe(el);
    }
    return () => observer.disconnect();
  }, [items]);

  return (
    <nav aria-label={label} className="sticky top-[76px] z-20 -mx-1 mb-5 overflow-x-auto px-1 no-print">
      <div className="glass-bar inline-flex min-w-max gap-1 rounded-2xl p-1">
        {items.map((item) => (
          <a
            key={item.id}
            href={`#${item.id}`}
            aria-current={active === item.id ? 'true' : undefined}
            onClick={(e) => {
              e.preventDefault();
              document.getElementById(item.id)?.scrollIntoView({ behavior: 'smooth', block: 'start' });
              setActive(item.id);
            }}
            className={cn(
              'h-8 rounded-xl px-3 text-[0.78rem] font-semibold leading-8 transition-colors',
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
