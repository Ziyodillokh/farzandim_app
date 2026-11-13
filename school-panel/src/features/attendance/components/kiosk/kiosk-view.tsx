'use client';

import { QrCode } from 'lucide-react';
import { useCallback, useState } from 'react';

import { Forbidden } from '@/auth/guards';
import { useCan, useSession } from '@/auth/use-session';
import { Button } from '@/components/ui/button';
import { ServiceError } from '@/data/contracts';
import { clockNow } from '@/data/mock/clock';
import { pickDemoCardUid } from '@/data/mock/demo-cards';
import { isHttpMode } from '@/data/source';
import { useCardTap } from '@/features/cards/hooks';
import type { CardRead } from '@/features/cards/nfc';
import { kioskId } from '@/features/cards/tap-queue';
import { playTone } from '@/features/cards/tone';
import { isRetryable, useTapQueue } from '@/features/cards/use-tap-queue';
import { signInKioskDuty } from '@/features/engine/kiosk-launch';
import { useI18n } from '@/i18n';
import { errorKey } from '@/lib/errors';
import { useKioskCheckIn, useKioskStats } from '../../hooks';
import { outcomeFromTap, toneFor } from './kiosk-card';
import { KioskHeader } from './kiosk-header';
import { KioskKeypad } from './kiosk-keypad';
import { KioskNfc } from './kiosk-nfc';
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

  const cardTap = useCardTap();
  const queue = useTapQueue();
  const { add: enqueue } = queue;
  // NFC karta: natija katta kartochkada va ovoz bilan; internet yo'q bo'lsa — navbatga.
  const runCard = useCallback(
    (read: CardRead) => {
      const payload = { ...read, kioskId: kioskId(), tappedAt: new Date().toISOString() };
      cardTap.mutate(payload, {
        onSuccess: (view) => {
          const next = outcomeFromTap(view);
          setOutcome(next);
          playTone(toneFor(next));
        },
        onError: (error) => {
          if (isRetryable(error)) {
            enqueue(payload);
            setOutcome({ kind: 'queued' });
            playTone('warn');
            return;
          }
          setOutcome({ kind: 'error', message: t(errorKey(error)) });
          playTone('fail');
        },
      });
    },
    [cardTap, enqueue, t],
  );

  // Demo: hali kelmagan o'quvchining kartasini "tegizish" (haqiqiy NFC'siz ko'rsatish uchun).
  const demoTap = useCallback(() => {
    const uid = pickDemoCardUid();
    if (uid) runCard({ uid });
  }, [runCard]);

  const closeResult = useCallback(() => setOutcome(null), []);

  return (
    // md+ (planshet/katta ekran): butun interfeys bitta ekranga (100dvh) sig'adi.
    <div className="dark relative min-h-[100dvh] bg-hero-gradient text-white md:h-[100dvh] md:overflow-y-auto">
      <style>{KEYFRAMES}</style>
      <div aria-hidden className="pointer-events-none fixed inset-0 overflow-hidden">
        <div className="absolute -right-40 -top-48 h-[34rem] w-[34rem] rounded-full bg-brand-600/25 blur-3xl" />
        <div className="absolute -bottom-56 -left-40 h-[36rem] w-[36rem] rounded-full bg-cyan-500/[0.12] blur-3xl" />
      </div>

      <div className="relative mx-auto flex min-h-full max-w-[1500px] flex-col gap-4 p-4 md:h-full md:gap-5 md:p-6 xl:gap-6 xl:px-10 xl:py-7">
        <KioskHeader />
        <KioskNfc onRead={runCard} queued={queue.size} onDemoTap={isHttpMode ? undefined : demoTap} />
        <main className="grid min-h-0 flex-1 items-stretch gap-4 md:grid-cols-2 md:gap-5 xl:gap-6">
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

/** Ruxsat yo'q (masalan, direktor): demo uchun shu tabni navbatchi sifatida ochish. */
function KioskForbidden() {
  const { t } = useI18n();
  const session = useSession();
  return (
    <div className="min-h-screen bg-background p-6">
      <Forbidden />
      <div className="mx-auto -mt-10 flex max-w-sm flex-col items-center gap-2 pb-10 text-center">
        <Button variant="soft" onClick={() => signInKioskDuty(session)}>
          <QrCode />
          {t('demo.kioskAsDuty')}
        </Button>
        <p className="text-xs text-muted-foreground">{t('demo.kioskAsDutyHint')}</p>
      </div>
    </div>
  );
}

/** Kirish nuqtasi — to'liq ekran; faqat `attendance.kiosk` ruxsati bilan. */
export function KioskView() {
  const can = useCan();
  if (!can('attendance.kiosk')) return <KioskForbidden />;
  return <KioskScreen />;
}
