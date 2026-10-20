'use client';

import { ArrowRight, ListChecks, MessageSquareHeart } from 'lucide-react';
import Link from 'next/link';
import type { ReactNode } from 'react';

import { Badge } from '@/components/ui/badge';
import { Card } from '@/components/ui/card';
import { useI18n } from '@/i18n';
import { useCareRequests } from '../hooks';

function QuickLink({ href, icon, title, children }: { href: string; icon: ReactNode; title: string; children?: ReactNode }) {
  return (
    <Link href={href} className="group block">
      <Card className="card-glow flex items-center gap-4 p-4">
        <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl bg-primary/10 text-primary ring-1 ring-inset ring-primary/15 [&_svg]:size-5">{icon}</span>
        <div className="min-w-0 flex-1">
          <p className="font-semibold">{title}</p>
          <div className="mt-1 flex flex-wrap gap-1.5">{children}</div>
        </div>
        <ArrowRight className="h-4 w-4 text-muted-foreground transition-all group-hover:translate-x-0.5 group-hover:text-primary" />
      </Card>
    </Link>
  );
}

/** Psixolog uchun tezkor havolalar (faqat `care.individual` bo'lsa ko'rsatiladi). */
export function PsychologistLinks() {
  const { t, tc } = useI18n();
  const requests = useCareRequests({});
  const urgentOpen = requests.data?.items.filter((r) => r.urgency === 'URGENT' && r.status !== 'RESOLVED').length ?? 0;
  const fresh = requests.data?.counts.NEW ?? 0;

  return (
    <section className="mb-6 animate-fade-in" aria-label={t('care.overview.psychologistTitle')}>
      <div className="mb-3">
        <h2 className="text-[0.95rem] font-semibold">{t('care.overview.psychologistTitle')}</h2>
        <p className="text-sm text-muted-foreground">{t('care.overview.psychologistHint')}</p>
      </div>
      <div className="grid gap-4 md:grid-cols-2">
        <QuickLink href="/care/requests" icon={<MessageSquareHeart />} title={t('care.overview.openRequests')}>
          {fresh > 0 && <Badge variant="info">{tc('care.overview.newRequests', fresh)}</Badge>}
          {urgentOpen > 0 && <Badge variant="destructive">{tc('care.overview.urgentRequests', urgentOpen)}</Badge>}
        </QuickLink>
        <QuickLink href="/care/surveys" icon={<ListChecks />} title={t('care.overview.openSurveys')} />
      </div>
    </section>
  );
}
