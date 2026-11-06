'use client';

import { Copy, KeyRound, Link2Off, UserCheck } from 'lucide-react';
import type { ReactNode } from 'react';

import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { SectionCard } from '@/components/common/section-card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import { INNER_TILE } from '@/features/classes/styles';
import { useCopy } from '@/features/parents/hooks';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { useCredentials } from '../hooks';

function Row({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex items-center justify-between gap-4 py-3 text-sm">
      <dt className="text-muted-foreground">{label}</dt>
      <dd className="min-w-0 text-right font-medium">{children}</dd>
    </div>
  );
}

/**
 * «Kirish maʼlumotlari»: login, kim bergan, holat; berish yoki tiklash (`students.manage`).
 * Faqat bola profiliga ulangan o'quvchiga beriladi — aks holda sababi tushuntiriladi (ota-ona avval ulashi kerak).
 */
export function CredentialsCard({ studentId, onIssue, onReset }: { studentId: string; onIssue: () => void; onReset: () => void }) {
  const { t, formatDate } = useI18n();
  const copy = useCopy();
  const query = useCredentials(studentId, true);
  const data = query.data;
  const credentials = data?.credentials ?? null;

  return (
    <SectionCard icon={<KeyRound />} title={t('access.credentials.title')} description={t('access.credentials.description')}>
      {query.isPending ? (
        <div className="space-y-3" aria-busy="true">
          <Skeleton className="h-10 w-full" />
          <Skeleton className="h-10 w-full" />
          <Skeleton className="h-10 w-2/3" />
        </div>
      ) : query.isError ? (
        <ErrorState error={query.error} onRetry={() => void query.refetch()} />
      ) : !data?.linked ? (
        <div data-testid="credentials-not-linked" className={cn('flex items-start gap-3 p-4', INNER_TILE)}>
          <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-warning/10 text-warning ring-1 ring-inset ring-warning/25 [&_svg]:size-[18px]">
            <Link2Off aria-hidden />
          </span>
          <div className="min-w-0 space-y-1">
            <p className="font-semibold">{t('access.credentials.notLinked.title')}</p>
            <p className="text-sm leading-relaxed text-muted-foreground">{t('access.credentials.notLinked.text')}</p>
            <p className="text-sm text-muted-foreground">{t('access.credentials.notLinked.hint')}</p>
          </div>
        </div>
      ) : !credentials ? (
        <EmptyState
          icon={<UserCheck />}
          title={t('access.credentials.none.title')}
          description={t('access.credentials.none.text')}
          className="py-6"
          action={
            <Button onClick={onIssue}>
              <KeyRound />
              {t('access.credentials.issue')}
            </Button>
          }
        />
      ) : (
        <div className="space-y-4">
          <dl className="divide-y divide-border/60 dark:divide-white/[0.06]" data-testid="credentials-details">
            <Row label={t('access.credentials.fields.login')}>
              <span className="inline-flex items-center gap-2">
                <span data-testid="credentials-login" className="font-mono">
                  {credentials.login}
                </span>
                <Button
                  type="button"
                  variant="ghost"
                  size="icon-sm"
                  onClick={() => void copy(credentials.login)}
                  aria-label={t('access.credentials.copyLogin')}
                  title={t('access.credentials.copyLogin')}
                >
                  <Copy />
                </Button>
              </span>
            </Row>
            <Row label={t('access.credentials.fields.issuedBy')}>{t(`access.credentials.issuer.${credentials.issuedBy}`)}</Row>
            <Row label={t('access.credentials.fields.issuedAt')}>{formatDate(credentials.issuedAt, 'dd.MM.yyyy, HH:mm')}</Row>
            <Row label={t('access.credentials.fields.password')}>
              <span className="flex flex-col items-end gap-1">
                <Badge variant={credentials.mustChangePassword ? 'warning' : 'success'}>
                  {t(credentials.mustChangePassword ? 'access.credentials.passwordState.temporary' : 'access.credentials.passwordState.set')}
                </Badge>
                {credentials.mustChangePassword && <span className="text-xs font-normal text-muted-foreground">{t('access.credentials.passwordState.temporaryHint')}</span>}
              </span>
            </Row>
            <Row label={t('access.credentials.fields.lastLogin')}>
              {credentials.lastLoginAt ? (
                formatDate(credentials.lastLoginAt, 'dd.MM.yyyy, HH:mm')
              ) : (
                <span className="text-muted-foreground">{t('access.credentials.neverLoggedIn')}</span>
              )}
            </Row>
          </dl>
          <Button type="button" variant="outline" onClick={onReset}>
            <KeyRound />
            {t('access.credentials.reset')}
          </Button>
        </div>
      )}
    </SectionCard>
  );
}
