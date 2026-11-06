'use client';

import { SchoolLogo } from '@/components/common/school-logo';
import { ParvozWordmark } from '@/components/layout/parvoz-wordmark';
import type { IssuedCredentials, School } from '@/data/contracts';
import { useI18n } from '@/i18n';

/**
 * Chop etiladigan kirish kartasi: login + vaqtinchalik parol + qisqa yo'riqnoma (bolaga murojaat «sen» shaklida).
 * Faqat `PrintOnly` ichida — parol ekranda va ochish oynasi yopilgach hech qayerda qolmaydi.
 */
export function CredentialPrintCard({
  issued,
  studentName,
  className,
  school,
}: {
  issued: IssuedCredentials;
  studentName: string;
  className: string;
  school: Pick<School, 'name' | 'shortName' | 'logo'> | undefined;
}) {
  const { t } = useI18n();
  return (
    <article data-testid="credential-print-card" className="mx-auto w-[96mm] rounded-2xl border-2 border-black p-6 text-black">
      <header className="flex items-center justify-between gap-3 border-b border-black/30 pb-3">
        <div className="flex min-w-0 items-center gap-2.5">
          <SchoolLogo school={school} className="h-10 w-10" />
          <p className="min-w-0 text-sm font-semibold leading-tight">{school?.name}</p>
        </div>
        <ParvozWordmark size="sm" className="shrink-0" />
      </header>
      <h2 className="mt-4 font-display text-lg font-semibold">{t('access.card.title')}</h2>
      <p className="mt-1 text-sm">
        <span className="font-semibold">{t('access.card.student')}:</span> {studentName} · {className}
      </p>
      <dl className="mt-4 space-y-3">
        <div className="rounded-xl border border-black/40 p-3">
          <dt className="text-xs font-semibold uppercase tracking-wide">{t('access.card.login')}</dt>
          <dd className="mt-1 break-all font-mono text-xl font-semibold">{issued.login}</dd>
        </div>
        <div className="rounded-xl border border-black/40 p-3">
          <dt className="text-xs font-semibold uppercase tracking-wide">{t('access.card.password')}</dt>
          <dd className="mt-1 break-all font-mono text-xl font-semibold tracking-[0.12em]">{issued.temporaryPassword}</dd>
        </div>
      </dl>
      <h3 className="mt-5 text-sm font-semibold">{t('access.card.howTitle')}</h3>
      <ol className="mt-1.5 list-decimal space-y-1 pl-5 text-sm">
        <li>{t('access.card.step1')}</li>
        <li>{t('access.card.step2')}</li>
        <li className="font-semibold">{t('access.card.step3')}</li>
      </ol>
      <p className="mt-4 border-t border-black/30 pt-3 text-xs">{t('access.card.footer')}</p>
    </article>
  );
}
