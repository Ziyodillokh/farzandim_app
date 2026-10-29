'use client';

import { useEffect, useState } from 'react';

import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

export const DASHBOARD_SECTIONS = ['kpis', 'map', 'insights', 'mastery', 'iq', 'interests', 'wellbeing', 'attendance', 'digital'] as const;
export type DashboardSection = (typeof DASHBOARD_SECTIONS)[number];

/** Bo'limlarga tez o'tish (yopishqoq), joriy bo'lim ajratiladi. */
export function SectionNav({ sections = DASHBOARD_SECTIONS, districts = false }: { sections?: readonly DashboardSection[]; districts?: boolean }) {
  const { t } = useI18n();
  const [active, setActive] = useState<string>(sections[0] ?? 'kpis');

  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        const visible = entries.filter((e) => e.isIntersecting).sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top)[0];
        if (visible) setActive(visible.target.id.replace('sec-', ''));
      },
      { rootMargin: '-120px 0px -55% 0px' },
    );
    for (const s of sections) {
      const el = document.getElementById(`sec-${s}`);
      if (el) observer.observe(el);
    }
    return () => observer.disconnect();
  }, [sections]);

  return (
    <nav aria-label={t('dashboard.nav')} className="sticky top-[76px] z-20 -mx-1 mb-5 overflow-x-auto px-1 no-print">
      <div className="glass-bar inline-flex min-w-max gap-1 rounded-2xl p-1">
        {sections.map((s) => (
          <a
            key={s}
            href={`#sec-${s}`}
            onClick={(e) => {
              e.preventDefault();
              document.getElementById(`sec-${s}`)?.scrollIntoView({ behavior: 'smooth', block: 'start' });
              setActive(s);
            }}
            className={cn(
              'h-8 rounded-xl px-3 text-[0.78rem] font-semibold leading-8 transition-colors',
              active === s ? 'bg-primary text-primary-foreground shadow-soft' : 'text-muted-foreground hover:text-foreground',
            )}
          >
            {s === 'map' && districts ? t('dashboard.sections.districts') : t(`dashboard.sections.${s}`)}
          </a>
        ))}
      </div>
    </nav>
  );
}
