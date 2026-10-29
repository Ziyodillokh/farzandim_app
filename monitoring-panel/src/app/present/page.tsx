'use client';

import { AuthGuard, HydrationGate } from '@/auth/guards';
import { useI18n } from '@/i18n';

/** Vaqtinchalik karkas — taqdimot rejimi tayyorlanmoqda. */
function Present() {
  const { t } = useI18n();
  return (
    <main className="flex min-h-screen items-center justify-center">
      <h1 className="font-display text-2xl">{t('present.title')}</h1>
    </main>
  );
}

export default function PresentPage() {
  return (
    <HydrationGate>
      <AuthGuard>
        <Present />
      </AuthGuard>
    </HydrationGate>
  );
}
