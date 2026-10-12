'use client';

import { BadgeCheck, MailQuestion, Send, UsersRound } from 'lucide-react';

import { StatCard } from '@/components/common/stat-card';
import type { ParentLinkStatus } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { percent } from '@/lib/utils';
import { useGuardianStats } from '../hooks';

const SEGMENTS: Array<{ key: ParentLinkStatus; className: string }> = [
  { key: 'LINKED', className: 'bg-success' },
  { key: 'INVITED', className: 'bg-warning' },
  { key: 'NOT_INVITED', className: 'bg-muted-foreground/30' },
];

/** Ulanish voronkasi: ulangan / taklif yuborilgan / taklif qilinmagan. */
export function ParentsStats() {
  const { t, formatNumber } = useI18n();
  const stats = useGuardianStats();
  const s = stats.data;
  const total = s?.total ?? 0;
  const share = (n: number) => `${percent(n, total)}%`;

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
        value={share(s?.LINKED ?? 0)}
        hint={formatNumber(s?.LINKED ?? 0)}
        loading={stats.isLoading}
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
