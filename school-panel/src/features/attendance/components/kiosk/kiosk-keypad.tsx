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

  // Balandlik ekran balandligiga moslashadi (1366×768 da ham bitta ekranga sig'adi).
  const key =
    'flex h-[clamp(2.75rem,7.2dvh,4.25rem)] items-center justify-center rounded-2xl border border-white/10 bg-white/[0.06] font-display text-2xl font-semibold transition-all hover:border-brand-400/40 hover:bg-white/[0.11] active:scale-95 disabled:opacity-40';

  return (
    <form onSubmit={submit} className="glass flex min-h-0 flex-col justify-center rounded-[1.75rem] p-5 xl:p-7">
      <p className="text-xs font-semibold uppercase tracking-[0.2em] text-brand-300 xl:text-sm">{t('attendance.kiosk.codeTitle')}</p>

      <label className="relative mt-4 flex h-[clamp(3.5rem,9dvh,5rem)] cursor-text items-center justify-center gap-1 rounded-2xl bg-brand-950/60 font-mono text-[clamp(1.9rem,5dvh,3rem)] font-semibold leading-none tracking-[0.2em] shadow-[inset_0_2px_12px_rgba(0,0,0,0.35)] ring-2 ring-brand-500/50 focus-within:ring-brand-400">
        <span className="text-white/45">{CODE_PREFIX}</span>
        {Array.from({ length: CODE_DIGITS }).map((_, i) => (
          <span key={i} className={cn('flex w-[0.8em] justify-center', digits[i] ? 'text-white' : 'text-white/25')}>
            {digits[i] ?? <span className="block h-[0.22em] w-[0.22em] rounded-full bg-current" aria-hidden />}
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

      <div className="mt-4 grid grid-cols-3 gap-2.5 xl:gap-3">
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
          className={cn(key, 'border-transparent bg-brand-gradient text-base shadow-[0_10px_30px_-10px_rgba(33,107,255,0.7)] hover:border-transparent hover:brightness-110 disabled:shadow-none')}
          aria-label={t('attendance.kiosk.submit')}
        >
          <Check className="h-7 w-7" />
        </button>
      </div>

      <button
        type="button"
        onClick={onOpenSearch}
        className="mt-4 inline-flex h-12 shrink-0 items-center justify-center gap-2 rounded-2xl border border-white/15 text-base font-semibold text-white/85 transition-colors hover:border-brand-400/40 hover:bg-white/[0.08] xl:h-14"
      >
        <Search className="h-5 w-5" />
        {t('attendance.kiosk.searchOpen')}
      </button>
    </form>
  );
}
