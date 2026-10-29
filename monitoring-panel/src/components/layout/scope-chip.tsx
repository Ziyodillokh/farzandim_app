'use client';

import { Landmark, MapPin } from 'lucide-react';

import { useSession } from '@/auth/use-session';
import { regionName } from '@/data/reference/regions';
import { useI18n } from '@/i18n';

/** Sidebar'dagi doira kartasi: respublika yoki viloyat. */
export function ScopeChip() {
  const { t, locale } = useI18n();
  const session = useSession();
  const regional = session?.role === 'REGIONAL' && session.regionId;
  return (
    <div className="mx-3 flex items-center gap-3 rounded-2xl bg-white/[0.04] p-2.5 ring-1 ring-inset ring-white/[0.07]">
      <span className="relative flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-brand-500/40 to-cyan-400/20 text-brand-200 ring-1 ring-inset ring-white/10">
        {regional ? <MapPin className="h-5 w-5" /> : <Landmark className="h-5 w-5" />}
        <span className="absolute -right-0.5 -top-0.5 h-2.5 w-2.5 rounded-full bg-emerald-400 shadow-[0_0_10px_rgba(52,211,153,0.9)] ring-2 ring-[hsl(var(--sidebar))]" />
      </span>
      <div className="min-w-0 leading-tight">
        <p className="truncate text-[0.85rem] font-semibold text-white">
          {regional ? regionName(session.regionId!, locale) : t('shell.scopeNational')}
        </p>
        <p className="mt-0.5 truncate text-[0.72rem] text-sidebar-muted">
          {regional ? t('shell.scopeRegionalSub') : t('shell.scopeNationalSub')}
        </p>
      </div>
    </div>
  );
}
