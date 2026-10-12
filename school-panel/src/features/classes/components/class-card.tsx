'use client';

import { ArrowRight, CalendarCheck2, DoorOpen, MoreHorizontal, Pencil, Smartphone, Trash2, UserRound, UsersRound } from 'lucide-react';
import Link from 'next/link';
import type { ReactNode } from 'react';

import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import { Progress } from '@/components/ui/progress';
import type { ClassRow } from '@/data/mock/services/classes';
import type { ClassBoardRow } from '@/data/mock/services/attendance';
import type { ClassModeState } from '@/data/mock/school-mode-state';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { ModeChip } from './mode-chip';

const GOOD_RATE = 90;
const WARN_RATE = 75;

export function rateTone(rate: number): string {
  if (rate >= GOOD_RATE) return 'text-success';
  if (rate >= WARN_RATE) return 'text-warning';
  return 'text-destructive';
}

function Metric({ icon, label, value, bar, barClass }: { icon: ReactNode; label: string; value: string; bar: number; barClass?: string }) {
  return (
    <div className="space-y-1.5">
      <div className="flex items-center justify-between gap-2 text-xs">
        <span className="flex items-center gap-1.5 text-muted-foreground [&_svg]:h-3.5 [&_svg]:w-3.5">
          {icon}
          {label}
        </span>
        <span className="font-semibold tabular-nums">{value}</span>
      </div>
      <Progress value={bar} className="h-1.5" indicatorClassName={barClass} />
    </div>
  );
}

function TodayLine({ board }: { board: ClassBoardRow | undefined }) {
  const { t } = useI18n();
  if (!board) return null;
  if (!board.schoolDay) return <p className="text-xs text-muted-foreground">{t('classes.card.notSchoolDay')}</p>;
  const decided = board.counts.total - board.counts.pending;
  if (decided === 0) return <p className="text-xs text-muted-foreground">{t('classes.card.noMarks')}</p>;
  return (
    <div className="flex items-center justify-between gap-2 text-xs">
      <span className="flex items-center gap-1.5 text-muted-foreground">
        <CalendarCheck2 className="h-3.5 w-3.5" />
        {t('classes.card.today')}
      </span>
      <span className="flex items-center gap-2 tabular-nums">
        <span className="text-muted-foreground">
          {board.counts.present + board.counts.late + board.counts.leftEarly}/{board.counts.total}
        </span>
        <span className={cn('font-display text-sm font-semibold', rateTone(board.rate))}>{board.rate}%</span>
      </span>
    </div>
  );
}

export type ClassCardProps = {
  row: ClassRow;
  board?: ClassBoardRow;
  mode?: ClassModeState;
  canManage: boolean;
  canSeeAttendance: boolean;
  onEdit: (row: ClassRow) => void;
  onDelete: (row: ClassRow) => void;
};

export function ClassCard({ row, board, mode, canManage, canSeeAttendance, onEdit, onDelete }: ClassCardProps) {
  const { t, tc } = useI18n();
  return (
    <Card className="card-glow group flex flex-col overflow-hidden animate-slide-up">
      <div className="flex items-start justify-between gap-3 p-5 pb-4">
        <Link href={`/classes/view?id=${row.id}`} className="min-w-0 rounded-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring">
          <p className="font-display text-2xl font-semibold leading-none tracking-tight transition-colors group-hover:text-primary">{row.name}</p>
          <p className="mt-2 flex items-center gap-1.5 text-xs text-muted-foreground">
            <DoorOpen className="h-3.5 w-3.5" />
            {row.room ? t('classes.card.room', { room: row.room }) : '—'}
            <span aria-hidden>·</span>
            {tc('common.studentsCount', row.size)}
          </p>
        </Link>
        <div className="flex shrink-0 items-center gap-1">
          {mode && <ModeChip state={mode} />}
          {canManage && (
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button variant="ghost" size="icon-sm" aria-label={t('classes.card.menu')}>
                  <MoreHorizontal />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end">
                <DropdownMenuItem onClick={() => onEdit(row)}>
                  <Pencil className="h-4 w-4" />
                  {t('common.edit')}
                </DropdownMenuItem>
                <DropdownMenuItem
                  onClick={() => onDelete(row)}
                  disabled={row.size > 0}
                  className="items-start text-destructive focus:text-destructive"
                >
                  <Trash2 className="mt-0.5 h-4 w-4" />
                  <span className="grid">
                    {t('common.delete')}
                    {row.size > 0 && <span className="max-w-[200px] text-2xs font-normal text-muted-foreground">{t('classes.delete.blocked')}</span>}
                  </span>
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          )}
        </div>
      </div>

      <div className="mx-5 flex items-center gap-2.5 rounded-lg bg-muted/60 px-3 py-2">
        <UserRound className="h-4 w-4 shrink-0 text-muted-foreground" />
        <span className={cn('truncate text-sm', row.homeroomName ? 'font-medium' : 'text-muted-foreground')}>
          {row.homeroomName ?? t('classes.card.noHomeroom')}
        </span>
      </div>

      <div className="space-y-3 p-5 pt-4">
        <Metric icon={<UsersRound />} label={t('classes.card.parentsLinked')} value={`${row.linkedRate}%`} bar={row.linkedRate} barClass="bg-success" />
        <Metric icon={<Smartphone />} label={t('classes.card.phones')} value={`${row.phoneRate}%`} bar={row.phoneRate} />
        {canSeeAttendance && <TodayLine board={board} />}
      </div>

      <div className="mt-auto flex items-center gap-2 border-t px-3 py-2.5">
        <Button asChild variant="ghost" size="sm" className="flex-1">
          <Link href={`/classes/view?id=${row.id}`}>
            {t('classes.card.open')}
            <ArrowRight />
          </Link>
        </Button>
        {canSeeAttendance && (
          <Button asChild variant="ghost" size="sm" className="flex-1">
            <Link href={`/attendance/class?id=${row.id}`}>
              <CalendarCheck2 />
              {t('classes.card.attendance')}
            </Link>
          </Button>
        )}
      </div>
    </Card>
  );
}
