'use client';

import { CheckCircle2, Search, X } from 'lucide-react';
import { useState } from 'react';

import { useI18n } from '@/i18n';
import { useDebounced } from '@/lib/use-debounced';
import { initials } from '@/lib/utils';
import { useKioskSearch } from '../../hooks';

/** Telefoni yo'q o'quvchi uchun: ism yoki kod bo'yicha qidirib belgilash (kiosk ichidagi panel). */
export function KioskSearch({ onClose, onMark, busy }: { onClose: () => void; onMark: (studentId: string) => void; busy: boolean }) {
  const { t } = useI18n();
  const [query, setQuery] = useState('');
  const debounced = useDebounced(query);
  const search = useKioskSearch(debounced);
  const tooShort = debounced.trim().length < 2;

  return (
    <div className="fixed inset-0 z-40 flex justify-end bg-brand-950/60 backdrop-blur-sm animate-fade-in" onClick={onClose}>
      <aside
        className="flex h-full w-full max-w-xl flex-col border-l border-white/10 bg-brand-900/95 p-6 shadow-[-30px_0_80px_-30px_rgba(0,0,0,0.8)] animate-slide-in-right md:p-8"
        onClick={(e) => e.stopPropagation()}
        aria-label={t('attendance.kiosk.searchTitle')}
      >
        <div className="flex items-start justify-between gap-4">
          <div>
            <h2 className="font-display text-2xl font-semibold">{t('attendance.kiosk.searchTitle')}</h2>
            <p className="mt-1 text-sm text-white/60">{t('attendance.kiosk.searchHint')}</p>
          </div>
          <button type="button" onClick={onClose} className="rounded-xl p-2 text-white/60 hover:bg-white/10 hover:text-white" aria-label={t('common.close')}>
            <X className="h-6 w-6" />
          </button>
        </div>

        <div className="relative mt-6">
          <Search className="pointer-events-none absolute left-4 top-1/2 h-5 w-5 -translate-y-1/2 text-white/40" />
          <input
            autoFocus
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={t('attendance.kiosk.searchPlaceholder')}
            className="h-14 w-full rounded-2xl border border-white/15 bg-white/[0.06] pl-12 pr-4 text-lg text-white placeholder:text-white/40 focus:border-brand-400/60 focus:outline-none focus:ring-2 focus:ring-brand-500/40"
          />
        </div>

        <div className="mt-4 flex-1 overflow-y-auto">
          {tooShort ? (
            <p className="py-10 text-center text-white/45">{t('attendance.kiosk.searchMin')}</p>
          ) : search.data?.length === 0 ? (
            <p className="py-10 text-center text-white/45">{t('common.noResults')}</p>
          ) : (
            <ul className="space-y-2">
              {search.data?.map((s) => (
                <li key={s.id} className="flex items-center gap-4 rounded-2xl border border-white/10 bg-white/[0.04] p-3 pl-4">
                  <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-brand-500/20 font-display text-sm font-semibold text-brand-300">
                    {initials(s.name)}
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-base font-semibold">{s.name}</p>
                    <p className="text-sm text-white/55">
                      {s.className} · {s.studentCode}
                    </p>
                  </div>
                  {s.inToday ? (
                    <span className="inline-flex items-center gap-1.5 rounded-xl bg-emerald-400/10 px-3 py-2 text-sm font-semibold text-emerald-300">
                      <CheckCircle2 className="h-4 w-4" />
                      {t('attendance.kiosk.alreadyShort')}
                    </span>
                  ) : (
                    <button
                      type="button"
                      disabled={busy}
                      onClick={() => onMark(s.id)}
                      className="h-11 rounded-xl bg-brand-gradient px-5 text-sm font-semibold text-white shadow-[0_8px_24px_-10px_rgba(33,107,255,0.8)] transition hover:brightness-110 disabled:opacity-50"
                    >
                      {t('attendance.kiosk.mark')}
                    </button>
                  )}
                </li>
              ))}
            </ul>
          )}
        </div>
      </aside>
    </div>
  );
}
