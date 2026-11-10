'use client';

import { useQuery } from '@tanstack/react-query';
import { ArrowLeft, KeyRound, Printer, RefreshCw } from 'lucide-react';
import Link from 'next/link';
import { useRouter, useSearchParams } from 'next/navigation';
import { useMemo, useState } from 'react';
import QRCode from 'react-qr-code';

import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { PageHeader } from '@/components/common/page-header';
import { SchoolLogo } from '@/components/common/school-logo';
import { FilterSelect, Toolbar } from '@/components/common/toolbar';
import { ParvozWordmark } from '@/components/layout/parvoz-wordmark';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { useSchool } from '@/features/school/hooks';
import { useClassOptions } from '@/features/students/hooks';
import { useI18n } from '@/i18n';
import { formatInviteCode, inviteLink } from '@/lib/invite-link';
import { fetchAllGuardians, type GuardianRow, parentKeys, useBulkInvite, useResend } from '../hooks';

const QR_SIZE = 132;

type Groups = { ready: GuardianRow[]; expired: GuardianRow[]; notInvited: number; linked: number };

function groupGuardians(rows: readonly GuardianRow[], now: number): Groups {
  const ready: GuardianRow[] = [];
  const expired: GuardianRow[] = [];
  let notInvited = 0;
  let linked = 0;
  for (const g of rows) {
    if (g.linkStatus === 'LINKED') linked += 1;
    else if (g.linkStatus === 'NOT_INVITED' || !g.inviteCode) notInvited += 1;
    else if (g.inviteExpiresAt && Date.parse(g.inviteExpiresAt) <= now) expired.push(g);
    else ready.push(g);
  }
  return { ready, expired, notInvited, linked };
}

/** Bitta oila varaqasi: maktab, farzand(lar), ota-ona, QR + kod, 3 qadam, amal muddati. */
function InviteCard({ guardian, schoolName, school }: { guardian: GuardianRow; schoolName: string; school: Parameters<typeof SchoolLogo>[0]['school'] }) {
  const { t, formatDate } = useI18n();
  const code = guardian.inviteCode ?? '';
  return (
    <article className="flex break-inside-avoid flex-col rounded-2xl border border-border/80 bg-card p-5 print:h-[124mm] print:rounded-xl print:p-4">
      <header className="flex items-center justify-between gap-3 border-b border-border/70 pb-3">
        <div className="flex min-w-0 items-center gap-2">
          <SchoolLogo school={school} className="h-8 w-8" />
          <p className="truncate text-sm font-semibold">{schoolName}</p>
        </div>
        <ParvozWordmark size="sm" sub="Parents" className="shrink-0" />
      </header>
      <div className="mt-3">
        <p className="text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">{t('parents.print.cardTitle')}</p>
        <p className="mt-1 text-base font-semibold leading-snug">{guardian.children.map((c) => c.name).join(', ') || '—'}</p>
        <p className="text-xs text-muted-foreground">
          {[...new Set(guardian.children.map((c) => c.className))].join(', ')} · {guardian.fullName}
        </p>
      </div>
      <div className="mt-3 flex flex-1 items-center gap-4">
        <div className="shrink-0 rounded-xl bg-white p-2 ring-1 ring-border">
          <QRCode value={inviteLink(code)} size={QR_SIZE} aria-label={code} />
        </div>
        <div className="min-w-0 space-y-2">
          <div>
            <p className="text-[11px] text-muted-foreground">{t('parents.print.code')}</p>
            <p className="font-mono text-2xl font-bold tracking-[0.12em]">{formatInviteCode(code)}</p>
          </div>
          <ol className="list-decimal space-y-0.5 pl-4 text-xs leading-snug text-foreground/85">
            <li>{t('parents.print.step1')}</li>
            <li>{t('parents.print.step2')}</li>
            <li>{t('parents.print.step3')}</li>
          </ol>
        </div>
      </div>
      {guardian.inviteExpiresAt && (
        <p className="mt-3 border-t border-border/70 pt-2 text-[11px] text-muted-foreground">
          {t('parents.print.validUntil', { date: formatDate(guardian.inviteExpiresAt, 'd MMMM yyyy') })} · farzandimedu.uz/link
        </p>
      )}
    </article>
  );
}

/**
 * Sinf bo'yicha taklif varaqalari (A4 ga 4 ta): ota-onalar majlisida tarqatish uchun. Faqat amaldagi kodlar
 * chop etiladi; kodi yo'q ota-onalarga shu yerning o'zida kod yaratiladi, muddati o'tganlari yangilanadi.
 */
export function InviteSheets() {
  const { t } = useI18n();
  const router = useRouter();
  const params = useSearchParams();
  const classId = params.get('classId') ?? undefined;
  const classes = useClassOptions();
  const school = useSchool();
  const bulk = useBulkInvite();
  const resend = useResend();
  const [refreshing, setRefreshing] = useState(false);
  const guardians = useQuery({
    queryKey: [...parentKeys.list({ classId, sortBy: 'name', sortDir: 'asc' }), 'print'],
    queryFn: () => fetchAllGuardians({ classId, sortBy: 'name', sortDir: 'asc' }),
  });
  const groups = useMemo(() => groupGuardians(guardians.data ?? [], Date.now()), [guardians.data]);
  const className = classes.data?.find((c) => c.id === classId)?.name;

  const refreshExpired = async () => {
    setRefreshing(true);
    try {
      for (const g of groups.expired) await resend.mutateAsync(g.id);
    } finally {
      setRefreshing(false);
    }
  };

  const schoolInfo = school.data?.school;
  return (
    <div className="mx-auto max-w-5xl">
      <div className="no-print">
        <div className="mb-4 flex items-center justify-between gap-3">
          <Button asChild variant="ghost" size="sm">
            <Link href="/parents">
              <ArrowLeft />
              {t('parents.title')}
            </Link>
          </Button>
          <Button onClick={() => window.print()} disabled={groups.ready.length === 0}>
            <Printer />
            {t('parents.print.print', { count: groups.ready.length })}
          </Button>
        </div>
        <PageHeader title={t('parents.print.title')} subtitle={t('parents.print.subtitle')} />
        <Toolbar>
          <FilterSelect
            value={classId}
            onChange={(next) => router.replace(next ? `/parents/print?classId=${encodeURIComponent(next)}` : '/parents/print')}
            options={(classes.data ?? []).map((c) => ({ value: c.id, label: c.name }))}
            allLabel={`${t('parents.filters.class')}: ${t('common.all')}`}
            className="sm:w-48"
          />
          {groups.notInvited > 0 && (
            <Button variant="soft" loading={bulk.isPending} onClick={() => bulk.mutate({ classId })}>
              <KeyRound />
              {t('parents.print.generate', { count: groups.notInvited })}
            </Button>
          )}
          {groups.expired.length > 0 && (
            <Button variant="soft" loading={refreshing} onClick={() => void refreshExpired()}>
              <RefreshCw />
              {t('parents.print.refreshExpired', { count: groups.expired.length })}
            </Button>
          )}
        </Toolbar>
        {guardians.data && (
          <p className="mb-5 text-sm text-muted-foreground">
            {t('parents.print.summary', { ready: groups.ready.length, linked: groups.linked, missing: groups.notInvited + groups.expired.length })}
            {className ? ` · ${className}` : ''}
          </p>
        )}
      </div>

      {guardians.isError ? (
        <ErrorState error={guardians.error} onRetry={() => void guardians.refetch()} />
      ) : guardians.isLoading ? (
        <div className="grid gap-4 sm:grid-cols-2">
          {Array.from({ length: 4 }, (_, i) => (
            <Skeleton key={i} className="h-72 rounded-2xl" />
          ))}
        </div>
      ) : groups.ready.length === 0 ? (
        <Card>
          <EmptyState icon={<KeyRound />} title={t('parents.print.empty')} description={t('parents.print.emptyHint')} />
        </Card>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 print:grid-cols-2 print:gap-3">
          {groups.ready.map((g) => (
            <InviteCard key={g.id} guardian={g} schoolName={schoolInfo?.name ?? ''} school={schoolInfo} />
          ))}
        </div>
      )}
    </div>
  );
}
