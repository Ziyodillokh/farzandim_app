'use client';

import { ArrowRight, ShieldX } from 'lucide-react';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect, useState, type ReactNode } from 'react';

import { Button } from '@/components/ui/button';
import { ParvozLogo } from '@/components/layout/parvoz-logo';
import { useI18n } from '@/i18n';
import { normalizePath } from '@/lib/base-path';
import { currentMe, restoreHttpSession } from '@/data/http/session';
import { forbiddenHints } from './forbidden-hints';
import { roleHas } from './permissions';
import { findRoute } from './route-manifest';
import { useSession } from './use-session';

/** localStorage o'qilguncha (gidratatsiya) — brend yuklovchisi; mos kelmaslik xatosi bo'lmaydi. */
export function HydrationGate({ children, fallback }: { children: ReactNode; fallback?: ReactNode }) {
  const [ready, setReady] = useState(false);
  useEffect(() => setReady(true), []);
  if (!ready) return <>{fallback ?? <FullScreenLoader />}</>;
  return <>{children}</>;
}

export function FullScreenLoader() {
  return (
    <div className="relative isolate flex min-h-screen items-center justify-center">
      <div aria-hidden className="aurora-bg" />
      <div className="flex flex-col items-center gap-5">
        <ParvozLogo decorative className="h-14 w-14 animate-pulse rounded-2xl shadow-primary-glow" />
        <div className="h-1 w-32 overflow-hidden rounded-full bg-primary/10">
          <div className="h-full w-1/2 animate-shimmer rounded-full bg-brand-gradient" />
        </div>
      </div>
    </div>
  );
}

/**
 * http rejim: access token faqat xotirada — sahifa ochilganda httpOnly cookie
 * orqali sessiya tiklanadi (bo'lmasa AuthGuard kirish sahifasiga o'tkazadi).
 */
export function HttpSessionGate({ children }: { children: ReactNode }) {
  const [ready, setReady] = useState(() => currentMe() !== null);
  useEffect(() => {
    if (ready) return;
    let alive = true;
    void restoreHttpSession().finally(() => {
      if (alive) setReady(true);
    });
    return () => {
      alive = false;
    };
  }, [ready]);
  if (!ready) return <FullScreenLoader />;
  return <>{children}</>;
}

export function AuthGuard({ children }: { children: ReactNode }) {
  const session = useSession();
  const router = useRouter();
  useEffect(() => {
    if (!session) router.replace('/login');
  }, [session, router]);
  if (!session) return <FullScreenLoader />;
  return <>{children}</>;
}

/** Sahifa ruxsati — manifestdagi `perm` bo'yicha. */
export function RouteGuard({ children }: { children: ReactNode }) {
  const session = useSession();
  const pathname = normalizePath(usePathname());
  const route = findRoute(pathname);
  if (session && route && !roleHas(session.role, route.perm)) return <Forbidden />;
  return <>{children}</>;
}

/** "Ruxsat yo'q": nima uchun yopiq, kimga ochiq va rolga ochiq muqobil bo'limlar (h1 matni o'zgarmas — e2e). */
export function Forbidden() {
  const { t } = useI18n();
  const session = useSession();
  const pathname = normalizePath(usePathname());
  const hint = session ? forbiddenHints(session.role, pathname) : null;
  const roles = hint?.allowedRoles.map((r) => t(`enums.role.${r}`)).join(', ');
  return (
    <div className="flex flex-col items-center justify-center gap-4 px-4 py-20 text-center animate-fade-in">
      <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-destructive/10 text-destructive">
        <ShieldX className="h-8 w-8" />
      </div>
      <div className="max-w-md space-y-2">
        <h1 className="font-display text-xl font-semibold">{t('auth.forbiddenTitle')}</h1>
        {hint?.sectionKey && session ? (
          <p className="text-sm text-muted-foreground">
            {t('auth.forbiddenSection', { section: t(hint.sectionKey), role: t(`enums.role.${session.role}`) })}
            {roles && ` ${t('auth.forbiddenAllowed', { roles })}`}
          </p>
        ) : (
          <p className="text-sm text-muted-foreground">{t('auth.forbiddenText')}</p>
        )}
        {hint && <p className="text-xs text-muted-foreground">{t(hint.adviceKey)}</p>}
      </div>
      {hint && hint.links.length > 0 && (
        <nav aria-label={t('auth.forbiddenLinks')} className="w-full max-w-xl">
          <p className="mb-2 text-2xs font-semibold uppercase tracking-[0.08em] text-muted-foreground">{t('auth.forbiddenLinks')}</p>
          <ul className="grid gap-2 sm:grid-cols-3">
            {hint.links.map((link) => (
              <li key={link.path}>
                <Link
                  href={link.path}
                  className="flex h-full items-center justify-between gap-2 rounded-xl bg-white/50 px-3 py-2.5 text-left text-sm font-medium ring-1 ring-inset ring-border/60 transition-colors hover:bg-primary/[0.06] hover:text-primary dark:bg-white/[0.03]"
                >
                  <span className="min-w-0 truncate">{t(link.titleKey)}</span>
                  <ArrowRight className="h-3.5 w-3.5 shrink-0 text-muted-foreground" aria-hidden />
                </Link>
              </li>
            ))}
          </ul>
        </nav>
      )}
      <Button asChild>
        <Link href="/dashboard">{t('auth.forbiddenBack')}</Link>
      </Button>
    </div>
  );
}
