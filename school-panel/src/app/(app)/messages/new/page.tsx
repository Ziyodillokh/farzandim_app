'use client';

import { useSearchParams } from 'next/navigation';
import { Suspense, useMemo } from 'react';

import { PageHeader } from '@/components/common/page-header';
import { Skeleton } from '@/components/ui/skeleton';
import { parseComposePrefill } from '@/features/messages/compose-prefill';
import { ComposeForm } from '@/features/messages/components/compose-form';
import { useI18n } from '@/i18n';

/** `?id=` — tahrirlash; `?classId=` / `?guardianId=g1,g2` — yangi xabar auditoriyasi oldindan tanlanadi. */
function ComposeView() {
  const { t } = useI18n();
  const params = useSearchParams();
  const id = params.get('id');
  const query = params.toString();
  const prefill = useMemo(() => parseComposePrefill(new URLSearchParams(query)), [query]);
  return (
    <>
      <PageHeader
        title={id ? t('messages.compose.editTitle') : t('messages.compose.title')}
        subtitle={t('messages.compose.subtitle')}
        backHref="/messages"
        backLabel={t('messages.compose.back')}
      />
      <ComposeForm id={id} prefill={prefill} />
    </>
  );
}

export default function NewMessagePage() {
  return (
    <Suspense fallback={<Skeleton className="h-[600px] w-full rounded-xl" />}>
      <ComposeView />
    </Suspense>
  );
}
