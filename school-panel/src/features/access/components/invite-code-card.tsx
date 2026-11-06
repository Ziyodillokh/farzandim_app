'use client';

import { CircleCheck, Clock, Copy, Printer, RefreshCw, Ticket } from 'lucide-react';
import { useCallback, useState } from 'react';

import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { SectionCard } from '@/components/common/section-card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import type { InviteSlot } from '@/data/contracts';
import { INNER_TILE } from '@/features/classes/styles';
import { useClockNow } from '@/features/engine/use-clock';
import { useCopy } from '@/features/parents/hooks';
import { useSchool } from '@/features/school/hooks';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { useGenerateInviteCode, useInviteCode } from '../hooks';
import { groupCode, plainCode, remainingUntil, spokenCode } from '../lib/format';
import { useFocusReturn } from '../lib/use-focus-return';
import { InvitePrintCard } from './invite-print-card';
import { PrintOnly } from './print-only';

/** Qolgan vaqt yangilanish davri: daqiqa aniqligi yetarli. */
const TICK_MS = 30_000;

function SlotChip({ slot, label }: { slot: InviteSlot; label: string }) {
  const { t } = useI18n();
  const Icon = slot.used ? CircleCheck : Clock;
  return (
    <Badge variant={slot.used ? 'success' : 'warning'} className="gap-1.5">
      <Icon className="h-3.5 w-3.5" aria-hidden />
      {label}: {t(slot.used ? 'access.invite.slotState.used' : 'access.invite.slotState.pending')}
    </Badge>
  );
}

/**
 * «Taklif kodi» (`guardians.link`): faol 6 xonali kod (3+3), muddat sanog'i, ikki o'rin (o'quvchi / ota-ona),
 * yangilash (tasdiq bilan) va chop etiladigan karta.
 */
export function InviteCodeCard({ studentId, studentName, className }: { studentId: string; studentName: string; className: string }) {
  const { t, formatDate } = useI18n();
  const copy = useCopy();
  const school = useSchool();
  const now = useClockNow(TICK_MS);
  const query = useInviteCode(studentId, true);
  const generate = useGenerateInviteCode(studentId);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [printJob, setPrintJob] = useState(0);
  const donePrinting = useCallback(() => setPrintJob(0), []);
  const focus = useFocusReturn();

  const invite = query.data ?? null;
  const remaining = invite ? remainingUntil(invite.expiresAt, now.getTime()) : null;
  const active = invite !== null && remaining !== null && !remaining.expired;

  const countdown = (() => {
    if (!remaining || remaining.expired) return null;
    if (remaining.hours === 0 && remaining.minutes === 0) return t('access.invite.lessThanMinute');
    const parts = [
      remaining.hours > 0 ? `${remaining.hours} ${t('common.hoursShort')}` : null,
      remaining.minutes > 0 ? `${remaining.minutes} ${t('common.minutesShort')}` : null,
    ].filter(Boolean);
    return t('access.invite.remaining', { time: parts.join(' ') });
  })();

  return (
    <SectionCard icon={<Ticket />} title={t('access.invite.title')} description={t('access.invite.description')}>
      {query.isPending ? (
        <div className="space-y-3" aria-busy="true">
          <Skeleton className="h-20 w-full" />
          <Skeleton className="h-6 w-2/3" />
        </div>
      ) : query.isError ? (
        <ErrorState error={query.error} onRetry={() => void query.refetch()} />
      ) : !invite || !active ? (
        <EmptyState
          icon={<Ticket />}
          title={invite ? t('access.invite.expired') : t('access.invite.none.title')}
          description={t('access.invite.none.text')}
          className="py-6"
          action={
            <Button onClick={() => generate.mutate()} loading={generate.isPending}>
              <Ticket />
              {t('access.invite.create')}
            </Button>
          }
        />
      ) : (
        <div className="space-y-4">
          <div className={cn('flex items-center justify-between gap-3 px-5 py-4', INNER_TILE)}>
            <p className="min-w-0 font-display text-4xl font-semibold tabular-nums tracking-[0.14em]">
              <span aria-hidden data-testid="invite-code" className="select-all">
                {groupCode(invite.code)}
              </span>
              <span className="sr-only">{spokenCode(invite.code)}</span>
            </p>
            <Button type="button" variant="outline" size="icon" onClick={() => void copy(plainCode(invite.code))} aria-label={t('access.invite.copy')} title={t('access.invite.copy')}>
              <Copy />
            </Button>
          </div>
          <p className="text-sm text-muted-foreground" data-testid="invite-expiry">
            <span className="font-medium text-foreground">{countdown}</span>
            {' · '}
            {t('access.invite.expiresAt', { date: formatDate(invite.expiresAt, 'd MMMM, HH:mm') })}
          </p>
          <ul aria-label={t('access.invite.slotsLabel')} className="flex flex-wrap gap-2">
            <li>
              <SlotChip slot={invite.student} label={t('access.invite.slot.student')} />
            </li>
            <li>
              <SlotChip slot={invite.parent} label={t('access.invite.slot.parent')} />
            </li>
          </ul>
          <p className="text-xs leading-relaxed text-muted-foreground">{t('access.invite.review')}</p>
          <div className="flex flex-wrap gap-2">
            <Button type="button" variant="outline" onClick={() => setPrintJob((n) => n + 1)}>
              <Printer />
              {t('access.invite.print')}
            </Button>
            <Button
              type="button"
              variant="soft"
              onClick={() => {
                focus.remember();
                setConfirmOpen(true);
              }}
              loading={generate.isPending}
            >
              <RefreshCw />
              {t('access.invite.regenerate')}
            </Button>
          </div>
        </div>
      )}

      <ConfirmDialog
        open={confirmOpen}
        onOpenChange={setConfirmOpen}
        title={t('access.invite.confirmTitle')}
        description={t('access.invite.confirmText')}
        confirmLabel={t('access.invite.confirm')}
        loading={generate.isPending}
        onConfirm={() => generate.mutate(undefined, { onSettled: () => setConfirmOpen(false) })}
        onCloseAutoFocus={focus.restore}
      />
      {active && invite && (
        <PrintOnly job={printJob} onDone={donePrinting}>
          <InvitePrintCard invite={invite} studentName={studentName} className={className} school={school.data?.school} />
        </PrintOnly>
      )}
    </SectionCard>
  );
}
