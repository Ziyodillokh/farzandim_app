'use client';

import { ArrowRight, Loader2 } from 'lucide-react';

import { DEMO_ACCOUNTS, type DemoAccount } from '@/auth/demo-accounts';
import { StaffAvatar } from '@/components/common/staff-avatar';
import { useDemoProfiles } from '@/features/profile/hooks';
import { useI18n } from '@/i18n';
import { shortName } from '@/lib/staff-avatar';
import { cn } from '@/lib/utils';

/** Demo hisoblar — portretli kartochkalar; bosilganda shu rol bilan darhol kiriladi. */
export function DemoAccountGrid({
  pendingUser,
  disabled,
  onPick,
}: {
  pendingUser: string | null;
  disabled: boolean;
  onPick: (account: DemoAccount) => void;
}) {
  const { t } = useI18n();
  const profiles = useDemoProfiles().data;

  return (
    <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
      {DEMO_ACCOUNTS.map((a, i) => {
        const p = profiles?.[a.staffId];
        const role = t(`enums.role.${a.role}`);
        const pending = pendingUser === a.username;
        return (
          <button
            key={a.username}
            type="button"
            disabled={disabled}
            onClick={() => onPick(a)}
            title={`${a.username} / ${a.password}`}
            aria-label={`${t('auth.loginAs', { role })} — ${p?.fullName ?? a.username}`}
            className={cn(
              'group relative flex items-center gap-2.5 rounded-xl bg-white/[0.04] p-2 pr-3 text-left ring-1 ring-inset ring-white/10 transition-all hover:bg-white/[0.08] hover:ring-primary/50 disabled:cursor-not-allowed disabled:opacity-60',
              i === DEMO_ACCOUNTS.length - 1 && DEMO_ACCOUNTS.length % 2 === 1 && 'sm:col-span-2',
              pending && 'bg-primary/15 ring-primary/60',
            )}
          >
            <StaffAvatar name={p?.fullName ?? a.username} photo={p?.photo ?? null} portrait={p?.portrait ?? null} size="md" className="ring-2 ring-white/10" />
            <span className="min-w-0 flex-1 leading-tight">
              <span className="block truncate text-[0.82rem] font-semibold text-white">{p ? shortName(p.fullName) : a.username}</span>
              <span className="mt-0.5 block truncate text-[0.7rem] text-brand-300">{role}</span>
            </span>
            {pending ? (
              <Loader2 className="absolute right-2.5 h-4 w-4 animate-spin text-brand-300" />
            ) : (
              <ArrowRight className="absolute right-2.5 h-4 w-4 text-white opacity-0 transition-all group-hover:translate-x-0.5 group-hover:opacity-100 max-sm:opacity-40" />
            )}
          </button>
        );
      })}
    </div>
  );
}
