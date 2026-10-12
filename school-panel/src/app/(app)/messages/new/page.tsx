'use client';

import { useSearchParams } from 'next/navigation';
import { Suspense } from 'react';

import { PageHeader } from '@/components/common/page-header';
import { Skeleton } from '@/components/ui/skeleton';
import { ComposeForm } from '@/features/messages/components/compose-form';
import { useI18n } from '@/i18n';

function ComposeView() {
  const { t } = useI18n();
  const id = useSearchParams().get('id');
  return (
    <>
      <PageHeader
        title={id ? t('messages.compose.editTitle') : t('messages.compose.title')}
        subtitle={t('messages.compose.subtitle')}
        backHref="/messages"
        backLabel={t('messages.compose.back')}
      />
      <ComposeForm id={id} />
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
