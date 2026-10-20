'use client';

import { ArrowRight, Brain, BriefcaseMedical, Library, MessageSquareHeart, Radio } from 'lucide-react';
import Link from 'next/link';
import type { ReactNode } from 'react';

import { useCan } from '@/auth/use-session';
import { SectionCard } from '@/components/common/section-card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { ICON_CHIP, TILE } from '@/features/dashboard/lib/tile';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

function Duty({ icon, title, badge, children }: { icon: ReactNode; title: string; badge?: string; children: ReactNode }) {
  return (
    <li className={cn(TILE, 'flex items-start gap-3 px-3.5 py-3')}>
      <span className={cn(ICON_CHIP, 'mt-0.5 h-8 w-8 rounded-lg bg-sky-500/10 text-sky-600 ring-sky-500/20 dark:text-sky-300 [&_svg]:size-4')}>{icon}</span>
      <div className="min-w-0">
        <div className="flex flex-wrap items-center gap-2 text-sm font-medium">
          <span>{title}</span>
          {badge && (
            <Badge variant="default" size="sm">
              {badge}
            </Badge>
          )}
        </div>
        <p className="mt-0.5 text-[0.8125rem] leading-relaxed text-muted-foreground">{children}</p>
      </div>
    </li>
  );
}

/**
 * "Psixolog ish maydoni" — so'rovnomalarni boshqarmaydigan rollar (direktor, admin) uchun
 * tushuntirish: psixolog nima qiladi va qaysi natijalar ularga umumlashgan holda keladi.
 */
export function PsychologistWorkspaceCard({ className }: { className?: string }) {
  const { t } = useI18n();
  const can = useCan();
  return (
    <SectionCard
      title={t('care.workspace.title')}
      description={t('care.workspace.hint')}
      icon={<BriefcaseMedical />}
      className={cn('flex flex-col', className)}
      bodyClassName="flex flex-1 flex-col p-3"
    >
      <ul className="space-y-2">
        <Duty icon={<Radio />} title={t('care.workspace.surveysTitle')}>
          {t('care.workspace.surveysText')}
        </Duty>
        <Duty icon={<Library />} title={t('care.workspace.bankTitle')}>
          {t('care.workspace.bankText')}
        </Duty>
        <Duty icon={<MessageSquareHeart />} title={t('care.workspace.requestsTitle')}>
          {t('care.workspace.requestsText')}
        </Duty>
        <Duty icon={<Brain />} title={t('care.workspace.testsTitle')} badge={t('care.workspace.new')}>
          {t('care.workspace.testsText')}
        </Duty>
      </ul>
      {can('development.view') && (
        <div className="mt-auto flex justify-end pt-3">
          <Button asChild variant="ghost" size="sm">
            <Link href="/development">
              {t('care.workspace.openDevelopment')}
              <ArrowRight />
            </Link>
          </Button>
        </div>
      )}
    </SectionCard>
  );
}
