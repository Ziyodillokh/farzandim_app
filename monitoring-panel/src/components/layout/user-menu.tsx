'use client';

import { ChevronDown, ChevronUp, LogOut, Moon, Sun } from 'lucide-react';
import { useTheme } from 'next-themes';
import { useRouter } from 'next/navigation';

import { signOut } from '@/auth/sign-in';
import { useSession } from '@/auth/use-session';
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
import { regionName } from '@/data/reference/regions';
import { useI18n, type Locale } from '@/i18n';
import { ParvozWordmark } from './parvoz-wordmark';

function useAccountTitle(): { title: string; role: string; initials: string } {
  const { t, locale } = useI18n();
  const session = useSession();
  if (!session) return { title: '…', role: '', initials: '?' };
  const title =
    session.role === 'REGIONAL' && session.regionId
      ? t('auth.accounts.REGIONAL', { region: regionName(session.regionId, locale, true) })
      : t('auth.accounts.NATIONAL');
  return { title, role: t(`shell.roles.${session.role}`), initials: session.username.slice(0, 2).toUpperCase() };
}

function Avatar({ initials, size = 'md' }: { initials: string; size?: 'sm' | 'md' | 'lg' }) {
  const cls = size === 'sm' ? 'h-8 w-8 text-[0.7rem]' : size === 'lg' ? 'h-11 w-11 text-sm' : 'h-10 w-10 text-xs';
  return (
    <span className={`${cls} flex shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-brand-500 to-cyan-500 font-display font-semibold text-white ring-2 ring-white/15`}>
      {initials}
    </span>
  );
}

/** Foydalanuvchi menyusi: hisob, mavzu, til, chiqish. */
export function UserMenu({ variant }: { variant: 'topbar' | 'sidebar' }) {
  const { t, locale, setLocale } = useI18n();
  const { theme, setTheme } = useTheme();
  const router = useRouter();
  const session = useSession();
  const { title, role, initials } = useAccountTitle();

  const trigger =
    variant === 'sidebar' ? (
      <button
        type="button"
        aria-label={t('shell.account')}
        className="group m-3 flex items-center gap-3 rounded-2xl bg-white/[0.04] p-2.5 text-left ring-1 ring-inset ring-white/[0.07] transition-colors hover:bg-white/[0.08]"
      >
        <Avatar initials={initials} />
        <span className="min-w-0 flex-1">
          <span className="block truncate text-sm font-semibold text-white">{title}</span>
          <span className="block truncate text-xs text-sidebar-muted">@{session?.username}</span>
        </span>
        <ChevronUp className="h-4 w-4 text-sidebar-muted transition-colors group-hover:text-white" />
      </button>
    ) : (
      <button
        type="button"
        aria-label={t('shell.account')}
        className="flex h-10 items-center gap-2 rounded-xl px-1.5 transition-colors hover:bg-primary/[0.06] dark:hover:bg-white/[0.06]"
      >
        <Avatar initials={initials} size="sm" />
        <ChevronDown className="hidden h-4 w-4 text-muted-foreground xl:block" />
      </button>
    );

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>{trigger}</DropdownMenuTrigger>
      <DropdownMenuContent align={variant === 'sidebar' ? 'start' : 'end'} side={variant === 'sidebar' ? 'top' : 'bottom'} className="w-72 p-1.5">
        <DropdownMenuLabel className="flex items-center gap-3 p-2 font-normal">
          <Avatar initials={initials} size="lg" />
          <span className="min-w-0">
            <span className="block truncate text-sm font-semibold">{title}</span>
            <span className="block truncate text-xs text-muted-foreground">
              {role} · @{session?.username}
            </span>
          </span>
        </DropdownMenuLabel>
        <DropdownMenuSeparator />
        <DropdownMenuLabel className="px-2 py-1 text-2xs font-semibold uppercase tracking-[0.12em] text-muted-foreground">{t('shell.theme')}</DropdownMenuLabel>
        <DropdownMenuRadioGroup value={theme ?? 'dark'} onValueChange={setTheme}>
          <DropdownMenuRadioItem value="dark" onSelect={(e) => e.preventDefault()}>
            <Moon className="mr-2 h-4 w-4" />
            {t('shell.themeDark')}
          </DropdownMenuRadioItem>
          <DropdownMenuRadioItem value="light" onSelect={(e) => e.preventDefault()}>
            <Sun className="mr-2 h-4 w-4" />
            {t('shell.themeLight')}
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
          className="text-destructive focus:bg-destructive/10 focus:text-destructive"
          onSelect={() => {
            signOut();
            router.replace('/login');
          }}
        >
          <LogOut />
          {t('auth.logout')}
        </DropdownMenuItem>
        <div className="mt-1 flex items-center justify-between border-t border-border/60 px-2 pb-1 pt-2.5">
          <ParvozWordmark size="xs" sub="Monitoring" />
          <span className="text-2xs text-muted-foreground">{t('shell.poweredBy')}</span>
        </div>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
