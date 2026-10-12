'use client';

import { Inbox, Lock, Siren } from 'lucide-react';
import { useCallback, useState } from 'react';

import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { PageHeader } from '@/components/common/page-header';
import { SearchInput, Toolbar } from '@/components/common/toolbar';
import { Skeleton } from '@/components/ui/skeleton';
import { Switch } from '@/components/ui/switch';
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs';
import type { CareRequestStatus } from '@/data/contracts';
import { CARE_REQUEST_STATUSES } from '@/data/schemas/care';
import { RequestListItem } from '@/features/care/components/request-list-item';
import { useCareRequests } from '@/features/care/hooks';
import { useI18n } from '@/i18n';

export default function CareRequestsPage() {
  const { t, tc } = useI18n();
  const [status, setStatus] = useState<CareRequestStatus>('NEW');
  const [search, setSearch] = useState('');
  const [urgentOnly, setUrgentOnly] = useState(false);
  const filter = { status, search: search || undefined, urgency: urgentOnly ? ('URGENT' as const) : undefined };
  const requests = useCareRequests(filter);
  const all = useCareRequests({});
  const urgentOpen = all.data?.items.filter((r) => r.urgency === 'URGENT' && r.status === 'NEW').length ?? 0;
  const onSearch = useCallback((value: string) => setSearch(value), []);

  const list = () => {
    if (requests.error) return <ErrorState error={requests.error} onRetry={() => void requests.refetch()} />;
    if (requests.isLoading) {
      return (
        <div className="space-y-3">
          {Array.from({ length: 4 }, (_, i) => (
            <Skeleton key={i} className="h-28 w-full rounded-xl" />
          ))}
        </div>
      );
    }
    const items = requests.data?.items ?? [];
    if (items.length === 0) {
      return (
        <EmptyState icon={<Inbox />} title={t('care.requests.empty')} description={t('care.requests.emptyHint')} className="rounded-xl border border-dashed" />
      );
    }
    return (
      <ul className="space-y-3 animate-fade-in">
        {items.map((r) => (
          <RequestListItem key={r.id} request={r} />
        ))}
      </ul>
    );
  };

  return (
    <>
      <PageHeader title={t('care.requests.title')} subtitle={t('care.requests.subtitle')} backHref="/care" backLabel={t('care.title')} />

      <div className="mb-5 flex items-start gap-3 rounded-xl border border-primary/15 bg-primary/[0.05] p-4 text-sm">
        <Lock className="mt-0.5 h-4 w-4 shrink-0 text-primary" />
        <p className="text-foreground/80">{t('care.requests.confidential')}</p>
      </div>

      {urgentOpen > 0 && (
        <button
          type="button"
          onClick={() => {
            setStatus('NEW');
            setUrgentOnly(true);
          }}
          className="mb-5 flex w-full items-center gap-3 rounded-xl border border-destructive/30 bg-destructive/[0.06] p-4 text-left text-sm font-medium text-destructive transition-colors hover:bg-destructive/10"
        >
          <span className="relative flex h-8 w-8 items-center justify-center rounded-lg bg-destructive/15">
            <span className="absolute inset-0 rounded-lg bg-destructive/20 animate-pulse-ring" aria-hidden />
            <Siren className="h-4 w-4" />
          </span>
          {tc('care.requests.urgentBanner', urgentOpen)}
        </button>
      )}

      <Tabs value={status} onValueChange={(v) => setStatus(v as CareRequestStatus)} className="mb-4">
        <TabsList className="h-auto flex-wrap justify-start">
          {CARE_REQUEST_STATUSES.map((s) => (
            <TabsTrigger key={s} value={s} className="gap-2">
              {t(`enums.careRequestStatus.${s}`)}
              <span className="rounded-full bg-muted-foreground/10 px-1.5 text-2xs tabular-nums">{requests.data?.counts[s] ?? 0}</span>
            </TabsTrigger>
          ))}
        </TabsList>
      </Tabs>

      <Toolbar>
        <SearchInput value={search} onChange={onSearch} placeholder={t('care.requests.searchPlaceholder')} />
        <label className="flex cursor-pointer items-center gap-2 rounded-lg border bg-card px-3 py-2 text-sm shadow-soft">
          <Switch checked={urgentOnly} onCheckedChange={setUrgentOnly} aria-label={t('care.requests.urgentOnly')} />
          {t('care.requests.urgentOnly')}
        </label>
      </Toolbar>

      {list()}
    </>
  );
}
