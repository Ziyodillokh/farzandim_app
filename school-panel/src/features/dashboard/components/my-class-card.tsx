'use client';

import { useQuery } from '@tanstack/react-query';
import Link from 'next/link';

import { SectionCard } from '@/components/common/section-card';
import { AttendanceBadge } from '@/components/common/status-badges';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import { api } from '@/data/api';
import { useI18n } from '@/i18n';

/** Sinf rahbari uchun: o'z sinfining bugungi ro'yxati. */
export function MyClassCard({ classId }: { classId: string }) {
  const { t } = useI18n();
  const day = useQuery({ queryKey: ['dashboard', 'my-class', classId], queryFn: () => api.attendance.classDay(classId) });

  return (
    <SectionCard
      title={day.data ? t('dashboard.myClass.title', { name: day.data.className }) : t('dashboard.myClass.titleFallback')}
      description={t('dashboard.myClass.subtitle')}
      actions={
        <Button asChild variant="ghost" size="sm">
          <Link href={`/attendance/class?id=${classId}`}>{t('dashboard.classes.open')}</Link>
        </Button>
      }
      bodyClassName="p-2"
    >
      {day.isLoading ? (
        <div className="grid gap-2 p-3 sm:grid-cols-2">
          {Array.from({ length: 8 }).map((_, i) => (
            <Skeleton key={i} className="h-9 rounded-lg" />
          ))}
        </div>
      ) : (
        <ul className="grid gap-x-4 sm:grid-cols-2">
          {day.data?.rows.map((r) => (
            <li key={r.studentId} className="flex items-center justify-between gap-2 border-b px-3 py-2 last:border-0">
              <Link href={`/students/view?id=${r.studentId}`} className="truncate text-sm hover:underline">
                {r.name}
              </Link>
              <span className="flex shrink-0 items-center gap-2">
                {r.record?.inAt && <span className="text-xs tabular-nums text-muted-foreground">{r.record.inAt}</span>}
                <AttendanceBadge status={r.record?.status ?? null} size="sm" />
              </span>
            </li>
          ))}
        </ul>
      )}
    </SectionCard>
  );
}
