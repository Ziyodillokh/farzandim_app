'use client';

import { KeyRound, TriangleAlert } from 'lucide-react';
import { useState } from 'react';

import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { ErrorState } from '@/components/common/error-state';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import type { RecoveryRequest } from '@/data/contracts';
import { INNER_TILE } from '@/features/classes/styles';
import { WARM_GLOW } from '@/features/messages/styles';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { useRecoveryRequests, useRejectRecovery } from '../hooks';
import { useFocusReturn } from '../lib/use-focus-return';

/**
 * Bolaning ochiq parol tiklash so'rovlari (CHILD_RECOVERY_REQUEST): «Parolni tiklash» (= kirish ma'lumotlarini tiklash oqimi)
 * va «Rad etish». Ochiq so'rov bo'lmasa karta ko'rinmaydi.
 */
export function RecoveryCard({ studentId, onReset }: { studentId: string; onReset: () => void }) {
  const { t, formatDate, formatRelative } = useI18n();
  const query = useRecoveryRequests(studentId, true);
  const reject = useRejectRecovery(studentId);
  const [target, setTarget] = useState<RecoveryRequest | null>(null);
  const focus = useFocusReturn();
  const requests = query.data ?? [];

  if (query.isError) {
    return (
      <Card>
        <ErrorState error={query.error} onRetry={() => void query.refetch()} />
      </Card>
    );
  }
  if (requests.length === 0) return null;

  return (
    <Card role="region" aria-labelledby="recovery-title" className="relative overflow-hidden animate-fade-in" data-testid="recovery-card">
      <div aria-hidden className={WARM_GLOW} />
      <div className="relative space-y-4 p-5">
        <div className="flex items-start gap-3">
          <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-warning/15 text-warning ring-1 ring-inset ring-warning/25 [&_svg]:size-[18px]">
            <TriangleAlert aria-hidden />
          </span>
          <div className="min-w-0">
            <h2 id="recovery-title" className="text-[0.95rem] font-semibold tracking-[-0.005em]">
              {t('access.recovery.title')}
              <Badge variant="warning" size="sm" className="ml-2 align-middle tabular-nums">
                {requests.length}
              </Badge>
            </h2>
            <p className="mt-0.5 text-sm text-muted-foreground">{t('access.recovery.description')}</p>
          </div>
        </div>
        <ul className="space-y-2">
          {requests.map((request) => (
            <li key={request.id} className={cn('flex flex-wrap items-center justify-between gap-3 px-4 py-3', INNER_TILE)} data-testid="recovery-request">
              <div className="flex min-w-0 items-center gap-2.5">
                <KeyRound className="h-4 w-4 shrink-0 text-warning" aria-hidden />
                <div className="min-w-0">
                  <p className="text-sm font-medium">{t('access.recovery.requested', { time: formatRelative(request.createdAt) })}</p>
                  <p className="mt-0.5 flex flex-wrap items-center gap-x-2 gap-y-1 text-xs text-muted-foreground">
                    <time dateTime={request.createdAt}>{formatDate(request.createdAt, 'dd.MM.yyyy, HH:mm')}</time>
                    {request.channel && (
                      <Badge variant="outline" size="sm">
                        {t(`access.recovery.channel.${request.channel}`)}
                      </Badge>
                    )}
                  </p>
                </div>
              </div>
              <div className="flex gap-2">
                <Button
                  size="sm"
                  variant="outline"
                  className="text-destructive hover:text-destructive"
                  onClick={() => {
                    focus.remember();
                    setTarget(request);
                  }}
                >
                  {t('access.recovery.reject')}
                </Button>
                <Button size="sm" onClick={onReset}>
                  <KeyRound />
                  {t('access.recovery.reset')}
                </Button>
              </div>
            </li>
          ))}
        </ul>
      </div>
      <ConfirmDialog
        open={Boolean(target)}
        onOpenChange={(open) => !open && setTarget(null)}
        title={t('access.recovery.rejectTitle')}
        description={t('access.recovery.rejectText')}
        confirmLabel={t('access.recovery.reject')}
        destructive
        loading={reject.isPending}
        onConfirm={() => {
          if (!target) return;
          reject.mutate(target.id, { onSettled: () => setTarget(null) });
        }}
        onCloseAutoFocus={focus.restore}
      />
    </Card>
  );
}
