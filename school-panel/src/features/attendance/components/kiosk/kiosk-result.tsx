'use client';

import { AlertTriangle, CheckCircle2, Clock4, Info, XCircle, type LucideIcon } from 'lucide-react';
import { useEffect } from 'react';

import type { AttendanceStatus } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

export const RESULT_HIDE_MS = 4000;

export type KioskOutcome =
  | { kind: 'success'; name: string; className: string; status: AttendanceStatus; time: string; already: boolean }
  | { kind: 'notFound'; code: string }
  | { kind: 'error'; message: string };

type Look = { icon: LucideIcon; ring: string; glow: string; bar: string };

const LOOKS: Record<'present' | 'late' | 'already' | 'failed', Look> = {
  present: { icon: CheckCircle2, ring: 'bg-emerald-400/15 text-emerald-300', glow: 'from-emerald-400/25', bar: 'bg-emerald-400' },
  late: { icon: Clock4, ring: 'bg-amber-400/15 text-amber-300', glow: 'from-amber-400/25', bar: 'bg-amber-400' },
  already: { icon: Info, ring: 'bg-[#3C82FF]/20 text-[#9CC0FF]', glow: 'from-[#3C82FF]/25', bar: 'bg-[#3C82FF]' },
  failed: { icon: XCircle, ring: 'bg-red-400/15 text-red-300', glow: 'from-red-400/25', bar: 'bg-red-400' },
};

function lookFor(outcome: KioskOutcome): Look {
  if (outcome.kind !== 'success') return LOOKS.failed;
  if (outcome.already) return LOOKS.already;
  return outcome.status === 'LATE' ? LOOKS.late : LOOKS.present;
}

/** Katta natija kartochkasi — 4 soniyadan keyin o'zi yopiladi (yoki bosilsa). */
export function KioskResult({ outcome, onClose }: { outcome: KioskOutcome; onClose: () => void }) {
  const { t } = useI18n();

  useEffect(() => {
    const id = setTimeout(onClose, RESULT_HIDE_MS);
    return () => clearTimeout(id);
  }, [outcome, onClose]);

  const look = lookFor(outcome);
  const Icon = outcome.kind === 'error' ? AlertTriangle : look.icon;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-[#060B16]/70 p-6 backdrop-blur-md animate-fade-in" onClick={onClose} role="alertdialog" aria-live="assertive">
      <div className={cn('relative w-full max-w-xl overflow-hidden rounded-[2rem] border border-white/10 bg-[#0B1428] bg-gradient-to-b to-[#0B1428] p-10 text-center shadow-2xl animate-slide-up', look.glow)}>
        <div className={cn('mx-auto flex h-24 w-24 items-center justify-center rounded-full', look.ring)}>
          <Icon className="h-14 w-14" strokeWidth={1.75} />
        </div>

        {outcome.kind === 'success' ? (
          <>
            <p className="mt-6 text-lg font-semibold text-white/70">
              {outcome.already ? t('attendance.kiosk.alreadyTitle') : outcome.status === 'LATE' ? t('attendance.kiosk.welcomeLate') : t('attendance.kiosk.welcome')}
            </p>
            <p className="mt-2 font-display text-4xl font-semibold leading-tight md:text-5xl">{outcome.name}</p>
            <div className="mt-6 flex flex-wrap items-center justify-center gap-3 text-base">
              <span className="rounded-full bg-white/10 px-4 py-1.5 font-display font-semibold">{outcome.className}</span>
              <span className={cn('rounded-full px-4 py-1.5 font-semibold', look.ring)}>{t(`enums.attendanceStatus.${outcome.status}`)}</span>
              <span className="rounded-full bg-white/10 px-4 py-1.5 font-mono font-semibold tabular-nums">{outcome.time}</span>
            </div>
            {outcome.already && <p className="mt-4 text-sm text-white/60">{t('attendance.kiosk.alreadyText')}</p>}
          </>
        ) : outcome.kind === 'notFound' ? (
          <>
            <p className="mt-6 font-display text-3xl font-semibold">{t('attendance.kiosk.notFoundTitle')}</p>
            <p className="mx-auto mt-3 max-w-md text-base text-white/70">{t('attendance.kiosk.notFoundText', { code: outcome.code })}</p>
          </>
        ) : (
          <>
            <p className="mt-6 font-display text-3xl font-semibold">{t('attendance.kiosk.errorTitle')}</p>
            <p className="mx-auto mt-3 max-w-md text-base text-white/70">{outcome.message}</p>
          </>
        )}

        <div className="absolute inset-x-0 bottom-0 h-1.5 bg-white/5">
          <div className={cn('h-full origin-left', look.bar)} style={{ animation: `kiosk-countdown ${RESULT_HIDE_MS}ms linear forwards` }} />
        </div>
      </div>
    </div>
  );
}
