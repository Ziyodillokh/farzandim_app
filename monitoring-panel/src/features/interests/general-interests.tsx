'use client';

import { BookOpen, ChefHat, Cpu, Dumbbell, Gamepad2, Heart, Microscope, Music, Palette, PawPrint, Plane, Rocket, Tv } from 'lucide-react';
import type { ReactNode } from 'react';

import { Section } from '@/components/common/section';
import { Skeleton } from '@/components/ui/skeleton';
import type { Interests } from '@/data/contracts';
import type { Interest } from '@/data/reference/domains';
import { Meter } from '@/features/mastery/kit/bars';
import { Note } from '@/features/mastery/kit/layout';
import { useI18n } from '@/i18n';
import { useMetricFormat } from '@/lib/format';
import { hasShares } from './leader';

const INTEREST_ICON: Record<Interest, ReactNode> = {
  games: <Gamepad2 />,
  sport: <Dumbbell />,
  tech: <Cpu />,
  cartoon: <Tv />,
  music: <Music />,
  animals: <PawPrint />,
  art: <Palette />,
  travel: <Plane />,
  science: <Microscope />,
  book: <BookOpen />,
  space: <Rocket />,
  food: <ChefHat />,
};

/** Umumiy qiziqishlar: 12 ta kartochka (belgi, nom, ulush), ulush bo'yicha kamayish tartibida; ulushlar yo'q — "ma'lumot yo'q". */
export function GeneralInterestsSection({ data, className }: { data: Interests | undefined; className?: string }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  return (
    <Section id="interests-general" icon={<Heart />} title={t('interests.sections.general')} subtitle={t('interests.sections.generalSub')} className={className}>
      {!data ? (
        <Skeleton className="h-[360px] w-full rounded-xl" />
      ) : !hasShares(data.general) ? (
        <Note>{t('common.noData')}</Note>
      ) : (
        <ul className="grid grid-cols-2 gap-2.5 sm:grid-cols-3">
          {data.general.map((g) => (
            <li key={g.key} className="rounded-xl bg-primary/[0.05] p-3 ring-1 ring-inset ring-border/50 dark:bg-white/[0.03]">
              <div className="flex items-center gap-2.5">
                <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-primary/10 text-primary ring-1 ring-inset ring-primary/15 [&_svg]:size-4">
                  {INTEREST_ICON[g.key]}
                </span>
                <span className="min-w-0">
                  <span className="block truncate text-[0.8rem] font-medium">{t(`enums.interest.${g.key}`)}</span>
                  <span className="block text-[0.95rem] font-semibold tabular-nums">{fmt.pct(g.share)}</span>
                </span>
              </div>
              <Meter value={g.share} className="mt-2.5" />
            </li>
          ))}
        </ul>
      )}
    </Section>
  );
}
