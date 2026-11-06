'use client';

import { FilePenLine, Link2, ShieldCheck } from 'lucide-react';
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
import { GlassCallout } from '@/features/messages/components/glass-callout';
import { type TKey, useI18n } from '@/i18n';

type Pending = { request: LinkRequest; decision: LinkDecision };

/** Tasdiq oynasi matnlari: (tur, qaror) → sarlavha, matn, tugma. */
const DIALOG: Record<LinkRequest['kind'], Record<LinkDecision, { title: TKey; text: TKey; confirm: TKey }>> = {
  REVIEW: {
    confirm: { title: 'linkRequests.review.confirmTitle', text: 'linkRequests.review.confirmText', confirm: 'linkRequests.review.confirm' },
    reject: { title: 'linkRequests.review.rejectTitle', text: 'linkRequests.review.rejectText', confirm: 'linkRequests.review.reject' },
  },
  CORRECTION: {
    confirm: { title: 'linkRequests.correction.keepTitle', text: 'linkRequests.correction.keepText', confirm: 'linkRequests.correction.keep' },
    reject: { title: 'linkRequests.correction.unlinkTitle', text: 'linkRequests.correction.unlinkText', confirm: 'linkRequests.correction.unlink' },
  },
};

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
  if (reviews.length === 0 && corrections.length === 0) {
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
  const [pending, setPending] = useState<Pending | null>(null);
  // Qaror qabul qilingach qator yo'qoladi — fokus belgilangan sahifa hududiga qaytadi.
  const region = useRef<HTMLDivElement>(null);
  const focus = useFocusReturn(() => region.current);
  const dialog = pending ? DIALOG[pending.request.kind][pending.decision] : null;

  const ask = (request: LinkRequest, decision: LinkDecision) => {
    focus.remember();
    setPending({ request, decision });
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
        open={Boolean(pending)}
        onOpenChange={(open) => !open && setPending(null)}
        title={dialog ? t(dialog.title) : ''}
        description={pending && dialog ? t(dialog.text, { name: pending.request.studentName, className: pending.request.className }) : undefined}
        confirmLabel={dialog ? t(dialog.confirm) : undefined}
        destructive={pending?.decision === 'reject'}
        loading={decide.isPending}
        onConfirm={() => {
          if (!pending) return;
          decide.mutate(pending, { onSettled: () => setPending(null) });
        }}
        onCloseAutoFocus={focus.restore}
      />
    </>
  );
}
