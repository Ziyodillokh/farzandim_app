'use client';

import { ScanLine } from 'lucide-react';
import { useEffect, useMemo, useState } from 'react';
import QRCode from 'react-qr-code';

import { api } from '@/data/api';
import { isHttpMode } from '@/data/source';
import { useI18n } from '@/i18n';

const TICK_MS = 250;
const WINDOW_SECONDS = 30;
const RING_RADIUS = 22;
const RING_LENGTH = 2 * Math.PI * RING_RADIUS;

/** Bir martalik QR (30 soniyalik oyna) va qolgan vaqt halqasi. */
export function KioskQr() {
  const { t } = useI18n();
  const [now, setNow] = useState(() => Date.now());

  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), TICK_MS);
    return () => clearInterval(id);
  }, []);

  const token = api.attendance.currentToken();
  const windowMs = WINDOW_SECONDS * 1000;
  const remainingMs = Math.min(windowMs, Math.max(0, Date.parse(token.expiresAt) - now));
  const seconds = Math.ceil(remainingMs / 1000);
  const progress = remainingMs / windowMs;
  const urgent = seconds <= 5;
  // QR faqat kod almashganda qayta chiziladi (har tikda emas).
  const qr = useMemo(
    () => (
      <QRCode
        value={`parvoz-school://checkin?code=${token.code}`}
        size={232}
        bgColor="#FFFFFF"
        fgColor="#060A15"
        level="M"
        className="h-[min(232px,52vw,30dvh)] w-[min(232px,52vw,30dvh)]"
      />
    ),
    [token.code],
  );

  return (
    <div className="glass flex min-h-0 flex-col items-center justify-center rounded-[1.75rem] p-5 text-center xl:p-7">
      <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.2em] text-brand-300 xl:text-sm">
        <ScanLine className="h-4 w-4" />
        {t('attendance.kiosk.scanTitle')}
      </div>

      <div className="relative mt-4 rounded-3xl bg-white p-4 shadow-[0_0_80px_-12px_rgba(60,130,255,0.6)] ring-1 ring-brand-300/40 xl:mt-6 xl:p-5">
        <div key={token.code} className="animate-fade-in">
          {qr}
        </div>
      </div>

      <div className="mt-4 flex items-center gap-4 xl:mt-6">
        <div className="relative h-14 w-14" role="timer" aria-label={t('attendance.kiosk.refreshIn', { seconds })}>
          <svg viewBox="0 0 52 52" className="h-14 w-14 -rotate-90">
            <circle cx="26" cy="26" r={RING_RADIUS} fill="none" stroke="rgba(255,255,255,0.12)" strokeWidth="4" />
            <circle
              cx="26"
              cy="26"
              r={RING_RADIUS}
              fill="none"
              stroke={urgent ? '#F5A524' : '#508AFF'}
              strokeWidth="4"
              strokeLinecap="round"
              strokeDasharray={RING_LENGTH}
              strokeDashoffset={RING_LENGTH * (1 - progress)}
            />
          </svg>
          <span className="absolute inset-0 flex items-center justify-center font-display text-sm font-semibold tabular-nums">{seconds}</span>
        </div>
        <div className="text-left">
          {/* Haqiqiy rejimda kod imzolangan uzun token — faqat QR orqali o'qiladi. */}
          {!isHttpMode && (
            <p className="font-mono text-xl font-semibold tracking-[0.3em] text-white/90 tabular-nums xl:text-2xl">
              {token.code.slice(0, 3)} {token.code.slice(3)}
            </p>
          )}
          <p className="mt-0.5 max-w-[240px] text-xs text-white/60">{t('attendance.kiosk.scanHint')}</p>
        </div>
      </div>
    </div>
  );
}
