'use client';

import { Nfc } from 'lucide-react';

import { Button } from '@/components/ui/button';
import { type CardRead, type NfcState, useNfcReader } from '@/features/cards/nfc';
import { primeAudio } from '@/features/cards/tone';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

const LABEL: Record<NfcState, 'cards.kiosk.title' | 'cards.kiosk.starting' | 'cards.kiosk.ready' | 'cards.kiosk.unsupported' | 'cards.kiosk.denied' | 'cards.kiosk.error'> = {
  idle: 'cards.kiosk.title',
  starting: 'cards.kiosk.starting',
  scanning: 'cards.kiosk.ready',
  unsupported: 'cards.kiosk.unsupported',
  denied: 'cards.kiosk.denied',
  error: 'cards.kiosk.error',
};

/**
 * NFC karta qatori: Web NFC holati, «NFC'ni yoqish» (brauzer tugma bosilishini talab qiladi),
 * oflayn navbat soni va demo'da karta tegizish tugmasi.
 */
export function KioskNfc({ onRead, queued, onDemoTap }: { onRead: (read: CardRead) => void; queued: number; onDemoTap?: () => void }) {
  const { t } = useI18n();
  const nfc = useNfcReader(onRead);
  const scanning = nfc.state === 'scanning';
  const canStart = nfc.state === 'idle' || nfc.state === 'denied' || nfc.state === 'error';

  return (
    <div className="glass flex flex-wrap items-center justify-between gap-3 rounded-[1.25rem] px-4 py-3 xl:px-5">
      <div className="flex min-w-0 items-center gap-3">
        <span className={cn('flex h-11 w-11 shrink-0 items-center justify-center rounded-full', scanning ? 'bg-emerald-400/15 text-emerald-300' : 'bg-white/10 text-white/70')}>
          <Nfc className={cn('h-6 w-6', scanning && 'animate-pulse')} />
        </span>
        <div className="min-w-0">
          <p className="font-display text-lg font-semibold leading-tight">{t(LABEL[nfc.state])}</p>
          {scanning && <p className="text-xs text-white/60">{t('cards.kiosk.readyHint')}</p>}
        </div>
      </div>
      <div className="flex flex-wrap items-center gap-2">
        {queued > 0 && <span className="rounded-full bg-amber-400/15 px-3 py-1 text-sm font-semibold tabular-nums text-amber-200">{t('cards.kiosk.queued', { count: queued })}</span>}
        {canStart && (
          <Button
            variant="soft"
            onClick={() => {
              primeAudio();
              void nfc.start();
            }}
          >
            <Nfc />
            {t('cards.kiosk.start')}
          </Button>
        )}
        {onDemoTap && (
          <Button variant="ghost" onClick={onDemoTap}>
            {t('cards.kiosk.demoTap')}
          </Button>
        )}
      </div>
    </div>
  );
}
