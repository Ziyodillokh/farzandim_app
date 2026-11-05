'use client';

import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { fromIsoDate } from '@/data/mock/calendar';
import { clockToday } from '@/data/mock/clock';
import type { AssignmentRow } from '@/data/mock/services/learning';
import { useI18n } from '@/i18n';
import { useAssignmentSubmissions } from '../hooks';
import { countSubmissions } from '../lib/submissions';

const DAY_MS = 86_400_000;
/** Muddati juda oldin o'tgan vazifalar uchun sanoq so'ralmaydi (ro'yxat uzayganda so'rovlar ko'payib ketmasin). */
export const COUNTER_WINDOW_DAYS = 45;

/** Muddatdan buyon o'tgan kunlar (kelajak — manfiy). */
function daysPastDue(dueDate: string): number {
  return Math.round((fromIsoDate(clockToday()).getTime() - fromIsoDate(dueDate).getTime()) / DAY_MS);
}

/** «12 / 25 topshirdi» + tekshirilmaganlar soni. Ma'lumot topshiriqlar paneli bilan bir xil keshdan. */
export function SubmissionCounter({ assignment }: { assignment: AssignmentRow }) {
  const { t } = useI18n();
  const query = useAssignmentSubmissions(assignment.id, daysPastDue(assignment.dueDate) <= COUNTER_WINDOW_DAYS);
  if (query.isLoading) return <Skeleton className="h-4 w-24" />;
  if (!query.data) return <span className="text-xs text-muted-foreground">—</span>;
  const counts = countSubmissions(query.data);
  return (
    <div className="flex flex-col items-start gap-1">
      <span className="whitespace-nowrap text-sm font-medium tabular-nums">{t('learning.submissions.counter', { submitted: counts.submitted, total: counts.total })}</span>
      {counts.pending > 0 && (
        <Badge variant="info" size="sm">
          {t('learning.submissions.pendingBadge', { count: counts.pending })}
        </Badge>
      )}
    </div>
  );
}
