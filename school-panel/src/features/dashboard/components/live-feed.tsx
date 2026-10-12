'use client';

import { LogIn, LogOut, Radio } from 'lucide-react';
import Link from 'next/link';

import { useCan } from '@/auth/use-session';
import { SectionCard } from '@/components/common/section-card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { useLiveFeed } from '../hooks';
import { ICON_CHIP, TILE } from '../lib/tile';

export function LiveFeed() {
  const { t, formatDate } = useI18n();
  const feed = useLiveFeed();
  // O'quvchi kartasi faqat `students.view` bilan ochiladi (navbatchida yo'q) — aks holda oddiy matn.
  const canOpenStudent = useCan()('students.view');

  return (
    <SectionCard
      title={
        <span className="flex items-center gap-2">
          {t('dashboard.feed.title')}
          <span className="relative flex h-2 w-2" aria-hidden>
            <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-success opacity-75" />
            <span className="relative inline-flex h-2 w-2 rounded-full bg-success" />
          </span>
        </span>
      }
      icon={<Radio />}
      actions={
        <Button asChild variant="ghost" size="sm">
          <Link href="/attendance/feed">{t('dashboard.feed.all')}</Link>
        </Button>
      }
      bodyClassName="p-3"
    >
      {feed.isLoading ? (
        <div className="space-y-2">
          {Array.from({ length: 6 }).map((_, i) => (
            <Skeleton key={i} className="h-12 rounded-xl" />
          ))}
        </div>
      ) : !feed.data?.length ? (
        <p className="px-4 py-12 text-center text-sm text-muted-foreground">{t('dashboard.feed.empty')}</p>
      ) : (
        <ul className="space-y-1.5">
          {feed.data.map((e) => (
            <li key={e.id} className={cn(TILE, 'flex items-center gap-3 px-2.5 py-2 animate-fade-in')}>
              <span
                className={cn(
                  ICON_CHIP,
                  'h-8 w-8 rounded-lg',
                  e.kind === 'IN' ? (e.late ? 'bg-warning/15 text-warning ring-warning/25' : 'bg-success/10 text-success ring-success/20') : 'bg-info/10 text-info ring-info/20',
                )}
              >
                {e.kind === 'IN' ? <LogIn className="h-4 w-4" /> : <LogOut className="h-4 w-4" />}
              </span>
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-medium">
                  {canOpenStudent ? (
                    <Link href={`/students/view?id=${e.studentId}`} className="hover:text-primary">
                      {e.studentName}
                    </Link>
                  ) : (
                    e.studentName
                  )}
                </p>
                <p className="text-xs text-muted-foreground">
                  {e.kind === 'OUT' ? t('dashboard.feed.out') : e.late ? t('dashboard.feed.lateIn') : t('dashboard.feed.in')}
                </p>
              </div>
              <Badge variant="outline" className="shrink-0">
                {e.className}
              </Badge>
              <span className="w-10 shrink-0 text-right text-xs tabular-nums text-muted-foreground">{formatDate(e.at, 'HH:mm')}</span>
            </li>
          ))}
        </ul>
      )}
    </SectionCard>
  );
}
