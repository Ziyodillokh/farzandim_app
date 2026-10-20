'use client';

import { ChevronDown, ChevronUp, LogOut, Monitor, Moon, Sun, UserRound } from 'lucide-react';
import { useTheme } from 'next-themes';
import { useRouter } from 'next/navigation';

import { setSession } from '@/auth/session';
import { StaffAvatar } from '@/components/common/staff-avatar';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Skeleton } from '@/components/ui/skeleton';
import { useProfileDialog } from '@/features/profile/components/profile-dialog-context';
import { useMe } from '@/features/profile/hooks';
import { isHttpMode } from '@/data/source';
import { httpSignOut } from '@/data/http/session';
import { useI18n, type Locale } from '@/i18n';
import { cn } from '@/lib/utils';
import { ParvozWordmark } from './parvoz-wordmark';

/** Foydalanuvchi menyusi: rasm, Profilim, mavzu, til, chiqish. Topbar va sidebar'da. */
export function UserMenu({ variant }: { variant: 'topbar' | 'sidebar' }) {
  const { t, locale, setLocale } = useI18n();
  const { theme, setTheme } = useTheme();
  const router = useRouter();
  const profile = useProfileDialog();
  const me = useMe().data;
  const role = me ? t(`enums.role.${me.role}`) : '';

  const trigger =
    variant === 'sidebar' ? (
      <button
        type="button"
        aria-label={t('shell.account')}
        className="group m-3 flex items-center gap-3 rounded-2xl bg-white/[0.04] p-2.5 text-left ring-1 ring-inset ring-white/[0.07] transition-colors hover:bg-white/[0.08]"
      >
        {me ? <StaffAvatar name={me.fullName} photo={me.photo} portrait={me.portrait} size="md" className="ring-2 ring-white/15" /> : <Skeleton className="h-10 w-10 rounded-full bg-white/10" />}
        <span className="min-w-0 flex-1">
          <span className="block truncate text-sm font-semibold text-white">{me?.fullName ?? '…'}</span>
          <span className="block truncate text-xs text-sidebar-muted">{role}</span>
        </span>
        <ChevronUp className="h-4 w-4 text-sidebar-muted transition-colors group-hover:text-white" />
      </button>
    ) : (
      <button
        type="button"
        aria-label={t('shell.account')}
        className="flex h-10 items-center gap-2 rounded-xl px-1.5 transition-colors hover:bg-primary/[0.06] dark:hover:bg-white/[0.06]"
      >
        {me ? <StaffAvatar name={me.fullName} photo={me.photo} portrait={me.portrait} size="sm" className="ring-2 ring-white dark:ring-white/10" /> : <Skeleton className="h-8 w-8 rounded-full" />}
        <span className="hidden max-w-[10rem] text-left leading-tight xl:block">
          <span className="block truncate text-[0.8rem] font-semibold">{me?.fullName.split(' ').slice(0, 2).reverse().join(' ')}</span>
          <span className="block truncate text-[0.7rem] text-muted-foreground">{role}</span>
        </span>
        <ChevronDown className="hidden h-4 w-4 text-muted-foreground xl:block" />
      </button>
    );

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>{trigger}</DropdownMenuTrigger>
      <DropdownMenuContent align={variant === 'sidebar' ? 'start' : 'end'} side={variant === 'sidebar' ? 'top' : 'bottom'} className="w-72 p-1.5">
        {me && (
          <DropdownMenuLabel className="flex items-center gap-3 p-2 font-normal">
            <StaffAvatar name={me.fullName} photo={me.photo} portrait={me.portrait} size="lg" />
            <span className="min-w-0">
              <span className="block truncate text-sm font-semibold">{me.fullName}</span>
              <span className="block truncate text-xs text-muted-foreground">
                {role}
                {me.username && ` · @${me.username}`}
              </span>
            </span>
          </DropdownMenuLabel>
        )}
        <DropdownMenuSeparator />
        <DropdownMenuItem onSelect={() => profile.open()}>
          <UserRound />
          {t('shell.myProfile')}
        </DropdownMenuItem>
        <DropdownMenuSeparator />
        <DropdownMenuLabel className="px-2 py-1 text-2xs font-semibold uppercase tracking-[0.12em] text-muted-foreground">{t('shell.theme')}</DropdownMenuLabel>
        <DropdownMenuRadioGroup value={theme ?? 'light'} onValueChange={setTheme}>
          <DropdownMenuRadioItem value="light" onSelect={(e) => e.preventDefault()}>
            <Sun className="mr-2 h-4 w-4" />
            {t('shell.themeLight')}
          </DropdownMenuRadioItem>
          <DropdownMenuRadioItem value="dark" onSelect={(e) => e.preventDefault()}>
            <Moon className="mr-2 h-4 w-4" />
            {t('shell.themeDark')}
          </DropdownMenuRadioItem>
          <DropdownMenuRadioItem value="system" onSelect={(e) => e.preventDefault()}>
            <Monitor className="mr-2 h-4 w-4" />
            {t('shell.themeSystem')}
          </DropdownMenuRadioItem>
        </DropdownMenuRadioGroup>
        <DropdownMenuSeparator />
        <DropdownMenuLabel className="px-2 py-1 text-2xs font-semibold uppercase tracking-[0.12em] text-muted-foreground">{t('shell.language')}</DropdownMenuLabel>
        <DropdownMenuRadioGroup value={locale} onValueChange={(v) => setLocale(v as Locale)}>
          <DropdownMenuRadioItem value="uz" onSelect={(e) => e.preventDefault()}>
            O&apos;zbekcha
          </DropdownMenuRadioItem>
          <DropdownMenuRadioItem value="ru" onSelect={(e) => e.preventDefault()}>
            Русский
          </DropdownMenuRadioItem>
        </DropdownMenuRadioGroup>
        <DropdownMenuSeparator />
        <DropdownMenuItem
          className={cn('text-destructive focus:bg-destructive/10 focus:text-destructive')}
          onSelect={() => {
            if (isHttpMode) {
              void httpSignOut().finally(() => router.replace('/login'));
              return;
            }
            setSession(null);
            router.replace('/login');
          }}
        >
          <LogOut />
          {t('auth.logout')}
        </DropdownMenuItem>
        <div className="mt-1 flex items-center justify-between border-t border-border/60 px-2 pb-1 pt-2.5">
          <ParvozWordmark size="xs" />
          <span className="text-2xs text-muted-foreground">{t('shell.poweredBy')}</span>
        </div>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
