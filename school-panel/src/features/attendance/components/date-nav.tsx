'use client';

import { CalendarDays, ChevronLeft, ChevronRight } from 'lucide-react';
import { useRef } from 'react';

import { Button } from '@/components/ui/button';
import type { IsoDate } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { addDays, fromIsoDate } from '../lib';

/**
 * Sana tanlovi: oldingi/keyingi kun, kalendar, "Bugun". Tarix ruxsati bo'lmasa
 * faqat bugungi sana ko'rsatiladi.
 */
export function DateNav({
  value,
  today,
  onChange,
  canHistory,
}: {
  value: IsoDate;
  today: IsoDate;
  onChange: (date: IsoDate) => void;
  canHistory: boolean;
}) {
  const { t, formatDate } = useI18n();
  const inputRef = useRef<HTMLInputElement>(null);
  const isToday = value >= today;
  const label = formatDate(fromIsoDate(value), 'd MMMM, EEEE');

  if (!canHistory) {
    return (
      <div className="flex h-10 items-center gap-2 rounded-lg border bg-card px-3 text-sm font-medium shadow-soft">
        <CalendarDays className="h-4 w-4 text-primary" />
        {label}
      </div>
    );
  }

  const openPicker = () => {
    const input = inputRef.current;
    if (!input) return;
    try {
      input.showPicker();
    } catch {
      input.focus();
    }
  };

  return (
    <div className="flex h-10 items-center gap-0.5 rounded-lg border bg-card p-1 shadow-soft">
      <Button variant="ghost" size="icon-sm" onClick={() => onChange(addDays(value, -1))} aria-label={t('attendance.date.prev')}>
        <ChevronLeft />
      </Button>
      <div className="relative">
        <Button variant="ghost" size="sm" className="h-8 gap-2 px-2.5 font-medium" onClick={openPicker} aria-label={t('attendance.date.label')}>
          <CalendarDays className="text-primary" />
          <span className="capitalize">{label}</span>
        </Button>
        <input
          ref={inputRef}
          type="date"
          tabIndex={-1}
          aria-hidden
          max={today}
          value={value}
          onChange={(e) => e.target.value && onChange(e.target.value > today ? today : e.target.value)}
          className="pointer-events-none absolute inset-x-0 bottom-0 h-0 w-full opacity-0"
        />
      </div>
      <Button variant="ghost" size="icon-sm" disabled={isToday} onClick={() => onChange(addDays(value, 1))} aria-label={t('attendance.date.next')}>
        <ChevronRight />
      </Button>
      {!isToday && (
        <Button variant="soft" size="sm" className="ml-0.5 h-8" onClick={() => onChange(today)}>
          {t('attendance.date.today')}
        </Button>
      )}
    </div>
  );
}
