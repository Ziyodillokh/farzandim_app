'use client';

import { SchoolLogo } from '@/components/common/school-logo';
import { ParvozWordmark } from '@/components/layout/parvoz-wordmark';
import type { InviteCode, School } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { groupCode } from '../lib/format';

/** Chop etiladigan taklif kodi kartasi: kod + maktab + bola va ota-ona ilovalari uchun qisqa yo'riqnoma. */
export function InvitePrintCard({
  invite,
  studentName,
  className,
  school,
}: {
  invite: InviteCode;
  studentName: string;
  className: string;
  school: Pick<School, 'name' | 'shortName' | 'logo'> | undefined;
}) {
  const { t, formatDate } = useI18n();
  return (
    <article data-testid="invite-print-card" className="mx-auto w-[96mm] rounded-2xl border-2 border-black p-6 text-black">
      <header className="flex items-center justify-between gap-3 border-b border-black/30 pb-3">
        <div className="flex min-w-0 items-center gap-2.5">
          <SchoolLogo school={school} className="h-10 w-10" />
          <p className="min-w-0 text-sm font-semibold leading-tight">{school?.name}</p>
        </div>
        <ParvozWordmark size="sm" className="shrink-0" />
      </header>
      <h2 className="mt-4 font-display text-lg font-semibold">{t('access.inviteCard.title')}</h2>
      <p className="mt-1 text-sm">
        <span className="font-semibold">{t('access.inviteCard.student')}:</span> {studentName} · {className}
      </p>
      <p className="mt-4 rounded-xl border-2 border-black py-4 text-center font-mono text-4xl font-bold tracking-[0.2em]">{groupCode(invite.code)}</p>
      <p className="mt-2 text-center text-xs">{t('access.inviteCard.validUntil', { date: formatDate(invite.expiresAt, 'd MMMM, HH:mm') })}</p>
      <div className="mt-5 space-y-3 text-sm">
        <section>
          <h3 className="font-semibold">{t('access.inviteCard.childTitle')}</h3>
          <p>{t('access.inviteCard.childText')}</p>
        </section>
        <section>
          <h3 className="font-semibold">{t('access.inviteCard.parentTitle')}</h3>
          <p>{t('access.inviteCard.parentText')}</p>
        </section>
      </div>
      <p className="mt-4 border-t border-black/30 pt-3 text-xs">{t('access.inviteCard.footer')}</p>
    </article>
  );
}
