'use client';

import { ShieldCheck } from 'lucide-react';
import { useSyncExternalStore, type ReactNode } from 'react';

import { ParvozWordmark } from '@/components/layout/parvoz-wordmark';
import { currentMe, subscribeMe } from '@/data/http/session';
import { useI18n } from '@/i18n';
import { PasswordChangeForm } from './password-change-form';

/**
 * http rejim: vaqtinchalik parol bilan kirgan xodim avval o'z parolini
 * o'rnatadi (server ham parol almashtirilguncha boshqa so'rovlarni 403 qiladi).
 */
export function ForcePasswordChange({ children }: { children: ReactNode }) {
  const { t } = useI18n();
  const me = useSyncExternalStore(subscribeMe, currentMe, () => null);
  if (!me?.mustChangePassword) return <>{children}</>;
  return (
    <div className="flex min-h-screen items-center justify-center bg-background px-4 py-10">
      <div className="w-full max-w-md">
        <div className="mb-6 flex justify-center">
          <ParvozWordmark size="lg" sub="School" />
        </div>
        <div className="rounded-3xl border bg-card p-6 shadow-glass sm:p-8">
          <div className="mb-5 flex items-start gap-3">
            <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-brand-50 text-brand-600 dark:bg-brand-500/15 dark:text-brand-300">
              <ShieldCheck className="h-5 w-5" />
            </span>
            <div>
              <h1 className="font-display text-xl font-semibold">{t('auth.changePassword.title')}</h1>
              <p className="mt-1 text-sm text-muted-foreground">{t('auth.changePassword.text')}</p>
            </div>
          </div>
          <PasswordChangeForm />
        </div>
      </div>
    </div>
  );
}
