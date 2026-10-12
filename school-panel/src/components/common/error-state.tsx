'use client';

import { AlertTriangle } from 'lucide-react';

import { Button } from '@/components/ui/button';
import { useI18n } from '@/i18n';
import { errorKey } from '@/lib/errors';
import { EmptyState } from './empty-state';

export function ErrorState({ error, onRetry }: { error: unknown; onRetry?: () => void }) {
  const { t } = useI18n();
  return (
    <EmptyState
      icon={<AlertTriangle />}
      title={t('common.error')}
      description={t(errorKey(error))}
      action={onRetry && <Button variant="outline" onClick={onRetry}>{t('common.retry')}</Button>}
    />
  );
}
