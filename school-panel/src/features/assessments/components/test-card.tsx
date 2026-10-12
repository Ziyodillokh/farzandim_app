'use client';

import { ClipboardList, Clock, Copy, FileJson, GraduationCap, ListChecks, MoreHorizontal, Send, Users } from 'lucide-react';
import Link from 'next/link';
import type { ReactNode } from 'react';

import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import type { PsychTestRow } from '@/data/mock/services/assessments';
import { TILE } from '@/features/dashboard/lib/tile';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { gradesLabel } from '../lib/labels';
import { KindIcon, SourceBadge, StatusBadge } from './test-badges';

export const viewHref = (id: string, tab?: string) => `/assessments/view?id=${encodeURIComponent(id)}${tab ? `&tab=${tab}` : ''}`;

export function isAssignable(test: Pick<PsychTestRow, 'status' | 'itemCount'>): boolean {
  return test.status === 'PUBLISHED' && test.itemCount > 0;
}

function Fact({ icon, children }: { icon: ReactNode; children: ReactNode }) {
  return (
    <div className={cn(TILE, 'flex items-center gap-1.5 whitespace-nowrap px-2.5 py-1.5 text-xs font-medium [&_svg]:size-3.5 [&_svg]:shrink-0 [&_svg]:text-muted-foreground')}>
      {icon}
      <span>{children}</span>
    </div>
  );
}

/** Kutubxonadagi test kartasi: turi, sinflar, savollar, vaqt va amallar. */
export function TestCard({
  test,
  onAssign,
  onDuplicate,
  onExport,
}: {
  test: PsychTestRow;
  onAssign: (test: PsychTestRow) => void;
  onDuplicate: (id: string) => void;
  onExport: (id: string) => void;
}) {
  const { t, tc, locale } = useI18n();
  const external = test.source === 'EXTERNAL';
  const description = test.description[locale] || (external ? t('assessments.library.externalHint') : t(`enums.psychKind.${test.kind}`));

  return (
    <Card className="card-glow flex flex-col p-5" data-testid={`test-card-${test.id}`}>
      <div className="flex items-start gap-3">
        <KindIcon kind={test.kind} />
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-1.5">
            <SourceBadge source={test.source} />
            <StatusBadge status={test.status} />
            {test.version > 1 && (
              <Badge variant="outline" size="sm">
                {t('assessments.view.version', { version: test.version })}
              </Badge>
            )}
          </div>
          <Link href={viewHref(test.id)} className="mt-1.5 line-clamp-2 block font-semibold leading-snug transition-colors hover:text-primary">
            {test.title[locale]}
          </Link>
        </div>
      </div>
      <p className="mt-2 line-clamp-2 min-h-[2.5rem] text-sm text-muted-foreground">{description}</p>

      <div className="mt-4 flex flex-wrap gap-2">
        <Fact icon={<GraduationCap />}>{gradesLabel(t, test.grades)}</Fact>
        <Fact icon={<ListChecks />}>{external ? '—' : tc('assessments.itemsCount', test.itemCount)}</Fact>
        <Fact icon={<Clock />}>{test.timeLimitMin ? t('assessments.minutes', { count: test.timeLimitMin }) : '—'}</Fact>
      </div>

      <div className="mt-3 flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-muted-foreground">
        <span className={cn('flex items-center gap-1.5', test.assignmentsActive > 0 && 'font-medium text-success')}>
          <Users className="h-3.5 w-3.5" />
          {t('assessments.library.activeAssignments', { count: test.assignmentsActive })}
        </span>
        <span className="flex items-center gap-1.5">
          <ClipboardList className="h-3.5 w-3.5" />
          {t('assessments.library.results', { count: test.resultsCount })}
        </span>
      </div>

      <div className="min-h-4 flex-1" aria-hidden />
      <div className="flex items-center gap-2 border-t border-border/50 pt-4 dark:border-white/[0.06]">
        <Button asChild variant="outline" size="sm" className="flex-1">
          <Link href={viewHref(test.id)}>{t('assessments.library.view')}</Link>
        </Button>
        {!external && (
          <Button size="sm" variant="soft" className="flex-1" disabled={!isAssignable(test)} onClick={() => onAssign(test)}>
            <Send />
            {t('assessments.library.assign')}
          </Button>
        )}
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" size="icon-sm" aria-label={t('assessments.library.more')}>
              <MoreHorizontal />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuItem onClick={() => onDuplicate(test.id)}>
              <Copy className="h-4 w-4" />
              {t('assessments.library.duplicate')}
            </DropdownMenuItem>
            <DropdownMenuItem onClick={() => onExport(test.id)}>
              <FileJson className="h-4 w-4" />
              {t('assessments.library.exportJson')}
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
    </Card>
  );
}
