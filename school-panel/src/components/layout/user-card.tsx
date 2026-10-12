'use client';

import { LogOut } from 'lucide-react';
import { useRouter } from 'next/navigation';

import { setSession } from '@/auth/session';
import { useSession } from '@/auth/use-session';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Button } from '@/components/ui/button';
import { useI18n } from '@/i18n';
import { useQuery } from '@tanstack/react-query';
import { getTables } from '@/data/mock/db';
import { initials } from '@/lib/utils';

export function UserCard() {
  const { t } = useI18n();
  const router = useRouter();
  const session = useSession();
  const { data: name } = useQuery({
    queryKey: ['me', session?.staffId],
    queryFn: () => getTables().staff.find((s) => s.id === session?.staffId)?.fullName ?? session?.username ?? '',
    enabled: Boolean(session),
  });
  if (!session) return null;

  return (
    <div className="m-3 flex items-center gap-3 rounded-xl border border-sidebar-border bg-white/[0.03] p-3">
      <Avatar className="h-9 w-9">
        <AvatarFallback className="bg-primary/20 text-xs font-semibold text-white">{initials(name)}</AvatarFallback>
      </Avatar>
      <div className="min-w-0 flex-1">
        <p className="truncate text-sm font-semibold text-white">{name}</p>
        <p className="truncate text-xs text-sidebar-muted">{t(`enums.role.${session.role}`)}</p>
      </div>
      <Button
        variant="ghost"
        size="icon-sm"
        className="text-sidebar-muted hover:bg-white/10 hover:text-white"
        aria-label={t('auth.logout')}
        title={t('auth.logout')}
        onClick={() => {
          setSession(null);
          router.replace('/login');
        }}
      >
        <LogOut />
      </Button>
    </div>
  );
}
