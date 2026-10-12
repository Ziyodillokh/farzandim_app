'use client';

import { ArrowRight } from 'lucide-react';
import { usePathname, useRouter } from 'next/navigation';
import { toast } from 'sonner';

import { DEMO_ACCOUNTS, type DemoAccount } from '@/auth/demo-accounts';
import { roleHas } from '@/auth/permissions';
import { findRoute } from '@/auth/route-manifest';
import { signIn } from '@/auth/sign-in';
import { useSession } from '@/auth/use-session';
import { StaffAvatar } from '@/components/common/staff-avatar';
import { Badge } from '@/components/ui/badge';
import { useDemoProfiles } from '@/features/profile/hooks';
import { useI18n } from '@/i18n';
import { normalizePath } from '@/lib/base-path';
import { shortName } from '@/lib/staff-avatar';
import { cn } from '@/lib/utils';

const SWITCH_SUMMARY = 'Demo panel orqali rol almashtirildi';

/** 5 ta demo hisob — bosilganda faqat shu tabda o'sha rolga o'tadi. */
export function RoleSwitcher({ onSwitched }: { onSwitched: () => void }) {
  const { t } = useI18n();
  const session = useSession();
  const router = useRouter();
  const pathname = normalizePath(usePathname());
  const profiles = useDemoProfiles().data;

  const switchTo = (account: DemoAccount) => {
    if (session?.staffId === account.staffId) return;
    signIn(account, 'tab', { summary: SWITCH_SUMMARY });
    const route = findRoute(pathname);
    if (!route || !roleHas(account.role, route.perm)) router.push('/dashboard');
    toast.success(t('demo.switchedTo', { role: t(`enums.role.${account.role}`) }));
    onSwitched();
  };

  return (
    <div className="grid gap-1.5">
      {DEMO_ACCOUNTS.map((account) => {
        const profile = profiles?.[account.staffId];
        const role = t(`enums.role.${account.role}`);
        const active = session?.staffId === account.staffId;
        return (
          <button
            key={account.username}
            type="button"
            onClick={() => switchTo(account)}
            aria-pressed={active}
            aria-label={`${t('demo.switchTo', { role })} — ${profile?.fullName ?? account.username}`}
            className={cn(
              'group flex items-center gap-3 rounded-xl border p-2 pr-3 text-left transition-all',
              active
                ? 'border-primary/40 bg-primary/[0.08] ring-1 ring-inset ring-primary/20'
                : 'border-border/60 bg-white/60 hover:border-primary/40 hover:bg-white dark:bg-white/[0.03] dark:hover:bg-white/[0.07]',
            )}
          >
            <StaffAvatar name={profile?.fullName ?? account.username} photo={profile?.photo ?? null} portrait={profile?.portrait ?? null} size="md" />
            <span className="min-w-0 flex-1 leading-tight">
              <span className="block truncate text-sm font-semibold">{profile ? shortName(profile.fullName) : account.username}</span>
              <span className="mt-0.5 block truncate text-xs text-muted-foreground">
                {role} · @{account.username}
              </span>
            </span>
            {active ? (
              <Badge size="sm">{t('demo.currentRole')}</Badge>
            ) : (
              <ArrowRight className="h-4 w-4 shrink-0 text-muted-foreground opacity-0 transition-all group-hover:translate-x-0.5 group-hover:text-primary group-hover:opacity-100" />
            )}
          </button>
        );
      })}
    </div>
  );
}
