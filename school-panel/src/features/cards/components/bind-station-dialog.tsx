'use client';

import { CheckCircle2, Nfc, SkipForward } from 'lucide-react';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';

import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Progress } from '@/components/ui/progress';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import type { CardReservation } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { formatCardNumber } from '@/lib/card-number';
import { errorKey } from '@/lib/errors';
import { cn } from '@/lib/utils';
import { useBindReservation } from '../batch-hooks';
import { useCardWedge } from '../card-wedge';
import { type CardRead, useNfcReader } from '../nfc';
import { playTone } from '../tone';

const ALL = 'all';
type Message = { ok: boolean; text: string };

/** Navbat: tanlangan sinf, bog'lanmaganlar; o'tkazib yuborilganlar oxirida (o'tkazilgan tartibda). */
function buildQueue(items: readonly CardReservation[], classId: string, done: ReadonlyMap<string, string | null>, skipped: readonly string[]) {
  const inClass = (c: string | null) => classId === ALL || c === classId;
  const pending = items.filter((i) => inClass(i.classId) && !done.has(i.id));
  const later = skipped.map((id) => pending.find((i) => i.id === id)).filter((i): i is CardReservation => Boolean(i));
  const doneHere = [...done.values()].filter(inClass).length;
  return { total: pending.length + doneHere, queue: [...pending.filter((i) => !skipped.includes(i.id)), ...later] };
}

/**
 * Ketma-ket biriktirish stansiyasi: ekranda navbatdagi o'quvchi va kartaga bosilgan raqam —
 * operator shu kartani o'qigichga tegizadi (USB yoki Android NFC), keyingisiga o'tiladi.
 */
export function BindStationDialog({ open, onOpenChange, items }: { open: boolean; onOpenChange: (open: boolean) => void; items: readonly CardReservation[] }) {
  const { t } = useI18n();
  const bind = useBindReservation();
  const [classId, setClassId] = useState(ALL);
  /** Bog'langanlar: id → sinf (ro'yxat yangilangach ham progress to'g'ri qolsin). */
  const [done, setDone] = useState<ReadonlyMap<string, string | null>>(new Map());
  const [skipped, setSkipped] = useState<readonly string[]>([]);
  const [message, setMessage] = useState<Message | null>(null);
  const busy = useRef(false);

  const classes = useMemo(() => {
    const seen = new Map<string, string>();
    for (const i of items) if (i.classId && !seen.has(i.classId)) seen.set(i.classId, i.className);
    return [...seen];
  }, [items]);
  const { total, queue } = useMemo(() => buildQueue(items, classId, done, skipped), [items, classId, done, skipped]);
  const current = queue[0];

  const onRead = useCallback(
    (read: CardRead) => {
      if (!current || busy.current) return;
      busy.current = true;
      bind.mutate(
        { id: current.id, input: read },
        {
          onSuccess: (card) => {
            setDone((prev) => new Map([...prev, [current.id, current.classId]]));
            setSkipped((prev) => prev.filter((id) => id !== current.id));
            setMessage({ ok: true, text: t('cards.batch.bound', { name: card.studentName, number: formatCardNumber(card.number) }) });
            playTone('ok');
          },
          onError: (error) => {
            setMessage({ ok: false, text: t(errorKey(error)) });
            playTone('fail');
          },
          onSettled: () => {
            busy.current = false;
          },
        },
      );
    },
    [bind, current, t],
  );

  useCardWedge(useCallback((uid: string) => onRead({ uid }), [onRead]), open);
  const nfc = useNfcReader(onRead);
  const { stop } = nfc;

  useEffect(() => {
    if (open) return;
    stop();
    setClassId(ALL);
    setDone(new Map());
    setSkipped([]);
    setMessage(null);
  }, [open, stop]);

  const doneCount = total - queue.length;
  const canStartNfc = nfc.state === 'idle' || nfc.state === 'denied' || nfc.state === 'error';

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-2xl">
        <DialogHeader>
          <DialogTitle>{t('cards.batch.stationTitle')}</DialogTitle>
          <DialogDescription>{t('cards.batch.stationHint')}</DialogDescription>
        </DialogHeader>

        <div className="flex flex-wrap items-center justify-between gap-3">
          <Select value={classId} onValueChange={setClassId}>
            <SelectTrigger className="w-full sm:w-52" aria-label={t('cards.batch.csv.className')}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value={ALL}>{t('cards.batch.allClasses')}</SelectItem>
              {classes.map(([id, name]) => (
                <SelectItem key={id} value={id}>
                  {name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          <span className="text-sm font-semibold tabular-nums text-muted-foreground">{t('cards.batch.progress', { done: doneCount, total })}</span>
        </div>
        <Progress value={total ? (doneCount / total) * 100 : 0} />

        {current ? (
          <div className="rounded-2xl border bg-muted/40 p-5 text-center" data-testid="station-current">
            <Badge variant="secondary">{current.className || '—'}</Badge>
            <p className="mt-3 font-display text-2xl font-semibold leading-tight sm:text-3xl">{current.studentName}</p>
            <p className="mt-1 text-sm text-muted-foreground">{current.studentCode}</p>
            <p className="mt-4 text-xs font-semibold uppercase tracking-[0.18em] text-muted-foreground">{t('cards.batch.csv.number')}</p>
            <p className="mt-1 font-mono text-3xl font-semibold tracking-[0.12em] tabular-nums sm:text-4xl">{formatCardNumber(current.number)}</p>
            <p className="mt-4 inline-flex items-center gap-2 text-sm text-muted-foreground">
              <Nfc className="h-4 w-4 animate-pulse text-primary" />
              {t('cards.kiosk.usbReady')}
            </p>
          </div>
        ) : (
          <div className="flex flex-col items-center gap-2 rounded-2xl border bg-muted/40 p-8 text-center">
            <CheckCircle2 className="h-10 w-10 text-emerald-500" />
            <p className="font-display text-xl font-semibold">{t('cards.batch.done')}</p>
          </div>
        )}

        {message && (
          <p role="status" className={cn('rounded-xl px-3 py-2 text-sm font-medium', message.ok ? 'bg-emerald-500/10 text-emerald-700 dark:text-emerald-300' : 'bg-destructive/10 text-destructive')}>
            {message.text}
          </p>
        )}
        {queue[1] && <p className="text-sm text-muted-foreground">{t('cards.batch.next', { name: queue[1].studentName })}</p>}

        <DialogFooter className="gap-2 sm:justify-between">
          <div>
            {nfc.state !== 'unsupported' && canStartNfc && (
              <Button type="button" variant="soft" onClick={() => void nfc.start()}>
                <Nfc />
                {t('cards.batch.nfcStart')}
              </Button>
            )}
          </div>
          <div className="flex gap-2">
            <Button type="button" variant="outline" disabled={!current || queue.length < 2} onClick={() => current && setSkipped((prev) => [...prev.filter((id) => id !== current.id), current.id])}>
              <SkipForward />
              {t('cards.batch.skip')}
            </Button>
            <Button type="button" onClick={() => onOpenChange(false)}>
              {t('common.close')}
            </Button>
          </div>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
