'use client';

import { ShieldX } from 'lucide-react';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect, useState, type ReactNode } from 'react';

import { Button } from '@/components/ui/button';
import { ParvozLogo } from '@/components/layout/parvoz-logo';
import { useI18n } from '@/i18n';
import { normalizePath } from '@/lib/base-path';
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

/** "Ruxsat yo'q" (h1 matni o'zgarmas — e2e shunga tayanadi). */
export function Forbidden() {
  const { t } = useI18n();
  return (
    <div className="flex flex-col items-center justify-center gap-4 px-4 py-20 text-center animate-fade-in">
      <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-destructive/10 text-destructive">
        <ShieldX className="h-8 w-8" />
      </div>
      <div className="max-w-md space-y-2">
        <h1 className="font-display text-xl font-semibold">{t('auth.forbiddenTitle')}</h1>
        <p className="text-sm text-muted-foreground">{t('auth.forbiddenText')}</p>
      </div>
      <Button asChild>
        <Link href="/dashboard">{t('auth.forbiddenBack')}</Link>
      </Button>
    </div>
  );
}
