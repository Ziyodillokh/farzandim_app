'use client';

import { useCallback, useState } from 'react';

import { Forbidden } from '@/auth/guards';
import { useCan } from '@/auth/use-session';
import { ServiceError } from '@/data/contracts';
import { clockNow } from '@/data/mock/clock';
import { useI18n } from '@/i18n';
import { errorKey } from '@/lib/errors';
import { useKioskCheckIn, useKioskStats } from '../../hooks';
import { KioskHeader } from './kiosk-header';
import { KioskKeypad } from './kiosk-keypad';
import { KioskQr } from './kiosk-qr';
import { KioskResult, type KioskOutcome } from './kiosk-result';
import { KioskSearch } from './kiosk-search';
import { KioskStats } from './kiosk-stats';
import { useKioskEngine } from './use-kiosk-engine';

const KEYFRAMES = '@keyframes kiosk-countdown { from { transform: scaleX(1); } to { transform: scaleX(0); } }';

function KioskScreen() {
  const { t, formatDate } = useI18n();
  useKioskEngine();
  const stats = useKioskStats();
  const checkIn = useKioskCheckIn();
  const [digits, setDigits] = useState('');
  const [searchOpen, setSearchOpen] = useState(false);
  const [outcome, setOutcome] = useState<KioskOutcome | null>(null);

  const run = useCallback(
    (codeOrId: string, displayCode: string) => {
      checkIn.mutate(codeOrId, {
        onSuccess: (res) =>
          setOutcome({
            kind: 'success',
            name: `${res.student.lastName} ${res.student.firstName}`,
            className: res.className,
            status: res.status,
            time: formatDate(clockNow(), 'HH:mm'),
            already: res.alreadyIn,
          }),
        onError: (error) =>
          setOutcome(
            error instanceof ServiceError && error.code === 'NOT_FOUND'
              ? { kind: 'notFound', code: displayCode }
              : { kind: 'error', message: t(errorKey(error)) },
          ),
        onSettled: () => setDigits(''),
      });
    },
    [checkIn, formatDate, t],
  );

  const closeResult = useCallback(() => setOutcome(null), []);

  return (
    <div className="dark relative min-h-screen overflow-hidden bg-hero-gradient text-white">
      <style>{KEYFRAMES}</style>
      <div className="pointer-events-none absolute -right-40 -top-40 h-[32rem] w-[32rem] rounded-full bg-primary/25 blur-3xl" />
      <div className="pointer-events-none absolute -bottom-48 -left-32 h-[34rem] w-[34rem] rounded-full bg-[#305399]/35 blur-3xl" />

      <div className="relative mx-auto flex min-h-screen max-w-[1500px] flex-col gap-6 p-5 md:gap-8 md:p-8 xl:p-10">
        <KioskHeader />
        <main className="grid flex-1 items-stretch gap-6 md:grid-cols-2 md:gap-8">
          <KioskQr />
          <KioskKeypad
            digits={digits}
            onDigitsChange={setDigits}
            onSubmit={(code) => run(code, code)}
            onOpenSearch={() => setSearchOpen(true)}
            busy={checkIn.isPending}
            active={!outcome && !searchOpen}
          />
        </main>
        <KioskStats stats={stats.data} />
      </div>

      {searchOpen && (
        <KioskSearch
          busy={checkIn.isPending}
          onClose={() => setSearchOpen(false)}
          onMark={(id) => {
            setSearchOpen(false);
            run(id, id);
          }}
        />
      )}
      {outcome && <KioskResult outcome={outcome} onClose={closeResult} />}
    </div>
  );
}

/** Kirish nuqtasi — to'liq ekran; faqat `attendance.kiosk` ruxsati bilan. */
export function KioskView() {
  const can = useCan();
  if (!can('attendance.kiosk')) {
    return (
      <div className="min-h-screen bg-background p-6">
        <Forbidden />
      </div>
    );
  }
  return <KioskScreen />;
}
