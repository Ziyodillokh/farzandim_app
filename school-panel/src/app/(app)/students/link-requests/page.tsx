'use client';

import { FilePenLine, Link2, ShieldCheck, UserCheck } from 'lucide-react';
import { useRef, useState } from 'react';

import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { PageHeader } from '@/components/common/page-header';
import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import type { LinkRequest } from '@/data/contracts';
import { useFocusReturn } from '@/features/access/lib/use-focus-return';
import { RequestSection } from '@/features/link-requests/components/request-section';
import { type LinkDecision, useDecideLinkRequest, useLinkRequests } from '@/features/link-requests/hooks';
import { LINK_ACTIONS } from '@/features/link-requests/lib/decisions';
import { GlassCallout } from '@/features/messages/components/glass-callout';
import { useI18n } from '@/i18n';

type Pending = { request: LinkRequest; decision: LinkDecision };

function ListSkeleton() {
  return (
    <div className="space-y-6" aria-busy="true">
      <Skeleton className="h-48 rounded-2xl" />
      <Skeleton className="h-32 rounded-2xl" />
    </div>
  );
}

/** Ro'yxat: yuklanish, xato, bo'sh holat yoki ikki bo'lim (tekshiruv kutayotganlar / tuzatish so'rovlari). */
function RequestsBody({ onDecide }: { onDecide: (request: LinkRequest, decision: LinkDecision) => void }) {
  const { t } = useI18n();
  const query = useLinkRequests();

  if (query.isError) {
    return (
      <Card>
        <ErrorState error={query.error} onRetry={() => void query.refetch()} />
      </Card>
    );
  }
  if (query.isPending) return <ListSkeleton />;

  const reviews = query.data.filter((r) => r.kind === 'REVIEW');
  const corrections = query.data.filter((r) => r.kind === 'CORRECTION');
  const guardians = query.data.filter((r) => r.kind === 'GUARDIAN');
  if (reviews.length === 0 && corrections.length === 0 && guardians.length === 0) {
    return (
      <Card>
        <EmptyState icon={<Link2 />} title={t('linkRequests.empty.title')} description={t('linkRequests.empty.text')} />
      </Card>
    );
  }
  return (
    <div className="space-y-6">
      {reviews.length > 0 && (
        <RequestSection
          id="link-review-title"
          icon={<Link2 aria-hidden />}
          title={t('linkRequests.review.title')}
          description={t('linkRequests.review.description')}
          requests={reviews}
          onDecide={onDecide}
        />
      )}
      {guardians.length > 0 && (
        <RequestSection
          id="link-guardian-title"
          icon={<UserCheck aria-hidden />}
          title={t('linkRequests.guardian.title')}
          description={t('linkRequests.guardian.description')}
          requests={guardians}
          onDecide={onDecide}
        />
      )}
      {corrections.length > 0 && (
        <RequestSection
          id="link-correction-title"
          icon={<FilePenLine aria-hidden />}
          title={t('linkRequests.correction.title')}
          description={t('linkRequests.correction.description')}
          requests={corrections}
          onDecide={onDecide}
        />
      )}
    </div>
  );
}

/** Ulanish so'rovlari: bola kodni kiritdi (tasdiqlash / rad etish) va tuzatish so'rovlari (ulanishni saqlash / uzish). */
export default function LinkRequestsPage() {
  const { t } = useI18n();
  const decide = useDecideLinkRequest();
  // `pending` yopilgandan keyin ham saqlanadi: yopilish animatsiyasi paytida oyna matni bo'sh qolmasin.
  const [pending, setPending] = useState<Pending | null>(null);
  const [open, setOpen] = useState(false);
  // Qaror qabul qilingach qator yo'qoladi — fokus belgilangan sahifa hududiga qaytadi.
  const region = useRef<HTMLDivElement>(null);
  const focus = useFocusReturn(() => region.current);
  const action = pending ? LINK_ACTIONS[pending.request.kind][pending.decision] : null;

  const ask = (request: LinkRequest, decision: LinkDecision) => {
    focus.remember();
    setPending({ request, decision });
    setOpen(true);
  };

  return (
    <>
      <PageHeader backHref="/students" backLabel={t('students.title')} title={t('linkRequests.title')} subtitle={t('linkRequests.subtitle')} />
      <GlassCallout icon={<ShieldCheck />} className="mb-6">
        {t('linkRequests.privacy')}
      </GlassCallout>
      <div ref={region} role="region" aria-label={t('linkRequests.listLabel')} tabIndex={-1} className="outline-none">
        <RequestsBody onDecide={ask} />
      </div>

      <ConfirmDialog
        open={open}
        onOpenChange={setOpen}
        title={action ? t(action.dialog.title) : ''}
        description={
          pending && action
            ? t(action.dialog.text, {
                name: pending.request.student.fullName,
                className: pending.request.student.className || '—',
                child: pending.request.child?.name ?? '—',
                parent: pending.request.parent?.name ?? '—',
              })
            : undefined
        }
        confirmLabel={action ? t(action.label) : undefined}
        destructive={action?.destructive}
        loading={decide.isPending}
        onConfirm={() => {
          if (!pending) return;
          void decide.decide(pending).then(undefined, () => undefined).finally(() => setOpen(false));
        }}
        onCloseAutoFocus={focus.restore}
      />
    </>
  );
}
