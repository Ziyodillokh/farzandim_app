'use client';

import { BadgeCheck, MailQuestion, Send, UsersRound } from 'lucide-react';

import { StatCard } from '@/components/common/stat-card';
import { Progress } from '@/components/ui/progress';
import type { ParentLinkStatus } from '@/data/contracts';
import { TILE } from '@/features/dashboard/lib/tile';
import { useI18n } from '@/i18n';
import { cn, percent } from '@/lib/utils';
import { useGuardianStats, useParentLinkSummary } from '../hooks';

const SEGMENTS: Array<{ key: ParentLinkStatus; className: string }> = [
  { key: 'LINKED', className: 'bg-success' },
  { key: 'INVITED', className: 'bg-warning' },
  { key: 'NOT_INVITED', className: 'bg-muted-foreground/30' },
];

/**
 * Ulanish voronkasi: ulangan / taklif yuborilgan / taklif qilinmagan.
 * "Ulangan" kartasida ikki ulush aniq nomi bilan: ota-onalar ulushi va o'quvchilar ulushi
 * (bosh sahifa KPI bilan bir xil manba — `parent-links.ts`).
 */
export function ParentsStats() {
  const { t, formatNumber } = useI18n();
  const stats = useGuardianStats();
  const links = useParentLinkSummary();
  const s = stats.data;
  const total = s?.total ?? 0;
  const g = links.data?.guardians;
  const st = links.data?.students;

  return (
    <div className="mb-6 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
      <StatCard
        icon={<UsersRound />}
        label={t('parents.stats.total')}
        value={formatNumber(total)}
        hint={t('parents.stats.totalHint')}
        loading={stats.isLoading}
        footer={
          s && (
            <div className="flex h-1.5 overflow-hidden rounded-full bg-muted" role="img" aria-label={t('parents.stats.linked')}>
              {SEGMENTS.map((seg) => (
                <span key={seg.key} className={seg.className} style={{ width: `${percent(s[seg.key], total)}%` }} />
              ))}
            </div>
          )
        }
      />
      <StatCard
        icon={<BadgeCheck />}
        tone="success"
        label={t('parents.stats.linked')}
        value={`${g?.rate ?? 0}%`}
        hint={
          g && (
            <>
              {t('parents.stats.guardianShare')} · {t('parents.stats.shareCount', { linked: formatNumber(g.linked), total: formatNumber(g.total) })}
            </>
          )
        }
        loading={links.isLoading}
        footer={
          st && (
            <div className={cn(TILE, 'space-y-1.5 px-3 py-2 text-xs')}>
              <div className="flex items-baseline justify-between gap-2">
                <span className="text-muted-foreground">{t('parents.stats.studentShare')}</span>
                <span className="font-semibold tabular-nums">{st.rate}%</span>
              </div>
              <div className="flex items-center gap-2">
                <Progress value={st.rate} className="h-1 flex-1" indicatorClassName="bg-info" aria-label={t('parents.stats.studentShare')} />
                <span className="shrink-0 text-2xs tabular-nums text-muted-foreground">
                  {t('parents.stats.shareCount', { linked: formatNumber(st.linked), total: formatNumber(st.total) })}
                </span>
              </div>
            </div>
          )
        }
      />
      <StatCard
        icon={<Send />}
        tone="warning"
        label={t('parents.stats.invited')}
        value={formatNumber(s?.INVITED ?? 0)}
        hint={t('parents.stats.invitedHint')}
        loading={stats.isLoading}
      />
      <StatCard
        icon={<MailQuestion />}
        tone="muted"
        label={t('parents.stats.notInvited')}
        value={formatNumber(s?.NOT_INVITED ?? 0)}
        hint={t('parents.stats.notInvitedHint')}
        loading={stats.isLoading}
      />
    </div>
  );
}
