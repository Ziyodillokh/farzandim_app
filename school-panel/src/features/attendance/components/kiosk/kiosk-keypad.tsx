'use client';

import { Check, Delete, Search } from 'lucide-react';
import { useEffect, useRef, type FormEvent, type MouseEvent } from 'react';

import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

export const CODE_PREFIX = 'P-';
export const CODE_DIGITS = 4;
const KEYS = ['1', '2', '3', '4', '5', '6', '7', '8', '9'] as const;
/** Tugma bosilganda fokus kod maydonida qoladi (skaner kiritishi yo'qolmasin). */
const keepFocus = (e: MouseEvent) => e.preventDefault();

/**
 * Shaxsiy kod kiritish: katta raqamli klaviatura (planshet), oddiy klaviatura yoki
 * shtrix-kod skaneri ("P-1234" yozadi). 4-raqam kiritilganda avtomatik yuboriladi.
 * `inputMode="none"` — planshetda ekran klaviaturasi chiqmaydi (o'zimizniki bor).
 */
export function KioskKeypad({
  digits,
  onDigitsChange,
  onSubmit,
  onOpenSearch,
  busy,
  active,
}: {
  digits: string;
  onDigitsChange: (digits: string) => void;
  onSubmit: (code: string) => void;
  onOpenSearch: () => void;
  busy: boolean;
  /** Natija yoki qidiruv oynasi yopiq — fokus kod maydoniga qaytadi (skaner/klaviatura uchun). */
  active: boolean;
}) {
  const { t } = useI18n();
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (active && !busy) inputRef.current?.focus({ preventScroll: true });
  }, [active, busy]);

  const update = (next: string) => {
    const clean = next.replace(/\D/g, '').slice(0, CODE_DIGITS);
    onDigitsChange(clean);
    if (clean.length === CODE_DIGITS && !busy) onSubmit(`${CODE_PREFIX}${clean}`);
  };

  const submit = (e: FormEvent) => {
    e.preventDefault();
    if (digits.length === CODE_DIGITS && !busy) onSubmit(`${CODE_PREFIX}${digits}`);
  };

  const key = 'flex h-16 items-center justify-center rounded-2xl border border-white/10 bg-white/[0.07] font-display text-2xl font-semibold transition-all hover:bg-white/[0.12] active:scale-95 disabled:opacity-40 md:h-[4.5rem]';

  return (
    <form onSubmit={submit} className="flex h-full flex-col rounded-[2rem] border border-white/10 bg-white/[0.04] p-6 backdrop-blur md:p-8">
      <p className="text-sm font-semibold uppercase tracking-[0.18em] text-[#9CC0FF]">{t('attendance.kiosk.codeTitle')}</p>

      <label className="relative mt-5 flex h-20 cursor-text items-center justify-center gap-1 rounded-2xl border-2 border-primary/50 bg-[#060B16]/60 font-mono text-4xl font-semibold tracking-[0.2em] shadow-[inset_0_2px_12px_rgba(0,0,0,0.35)] md:text-5xl">
        <span className="text-white/45">{CODE_PREFIX}</span>
        {Array.from({ length: CODE_DIGITS }).map((_, i) => (
          <span key={i} className={cn('w-[0.8em] text-center', digits[i] ? 'text-white' : 'text-white/20')}>
            {digits[i] ?? '_'}
          </span>
        ))}
        <input
          ref={inputRef}
          value={digits}
          onChange={(e) => update(e.target.value)}
          inputMode="none"
          autoComplete="off"
          aria-label={t('attendance.kiosk.codePlaceholder')}
          className="absolute inset-0 h-full w-full cursor-text opacity-0"
        />
      </label>

      <div className="mt-5 grid grid-cols-3 gap-3">
        {KEYS.map((k) => (
          <button key={k} type="button" className={key} disabled={busy} onMouseDown={keepFocus} onClick={() => update(digits + k)}>
            {k}
          </button>
        ))}
        <button type="button" className={cn(key, 'text-base text-white/70')} disabled={busy || !digits} onMouseDown={keepFocus} onClick={() => update(digits.slice(0, -1))} aria-label={t('attendance.kiosk.backspace')}>
          <Delete className="h-6 w-6" />
        </button>
        <button type="button" className={key} disabled={busy} onMouseDown={keepFocus} onClick={() => update(digits + '0')}>
          0
        </button>
        <button
          type="submit"
          onMouseDown={keepFocus}
          disabled={busy || digits.length < CODE_DIGITS}
          className={cn(key, 'border-transparent bg-primary text-base hover:bg-primary-glow')}
          aria-label={t('attendance.kiosk.submit')}
        >
          <Check className="h-7 w-7" />
        </button>
      </div>

      <button
        type="button"
        onClick={onOpenSearch}
        className="mt-5 inline-flex h-14 items-center justify-center gap-2 rounded-2xl border border-white/15 text-base font-semibold text-white/85 transition-colors hover:bg-white/[0.08]"
      >
        <Search className="h-5 w-5" />
        {t('attendance.kiosk.searchOpen')}
      </button>
    </form>
  );
}
