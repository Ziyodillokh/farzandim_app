'use client';

import { ChevronDown, ExternalLink } from 'lucide-react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useState } from 'react';

import { useCan, useSession } from '@/auth/use-session';
import { SchoolLogo } from '@/components/common/school-logo';
import { ScrollArea } from '@/components/ui/scroll-area';
import { useSchool } from '@/features/school/hooks';
import { useI18n } from '@/i18n';
import { normalizePath } from '@/lib/base-path';
import { cn } from '@/lib/utils';
import { buildNav, type NavNode } from './nav-items';
import { ParvozWordmark } from './parvoz-wordmark';
import { UserMenu } from './user-menu';

function isActive(pathname: string, href: string): boolean {
  return pathname === href || pathname.startsWith(`${href}/`);
}

function NavLink({ node, pathname, onNavigate }: { node: NavNode; pathname: string; onNavigate?: () => void }) {
  const { t } = useI18n();
  const Icon = node.icon;
  const hasChildren = node.children.length > 1;
  const active = isActive(pathname, node.path);
  const [open, setOpen] = useState(active);

  const itemClass = (on: boolean) =>
    cn(
      'group relative flex h-10 w-full items-center gap-3 rounded-xl px-3 text-[0.88rem] font-medium transition-all',
      on
        ? 'bg-gradient-to-r from-primary/35 to-primary/[0.06] text-white shadow-[0_8px_20px_-12px_hsl(var(--primary)/0.9)] ring-1 ring-inset ring-white/[0.08] [&>svg:first-of-type]:text-brand-300'
        : 'text-sidebar-muted hover:bg-white/[0.05] hover:text-white',
    );
  const edge = <span className="absolute left-0 top-1/2 h-5 w-1 -translate-y-1/2 rounded-r-full bg-brand-400 shadow-[0_0_12px_rgba(80,138,255,0.9)]" />;

  if (node.external) {
    return (
      <a href={`${process.env.NEXT_PUBLIC_BASE_PATH ?? ''}${node.path}/`} target="_blank" rel="noreferrer" className={itemClass(false)}>
        <Icon className="h-[18px] w-[18px] shrink-0" />
        <span className="truncate">{t(node.titleKey)}</span>
        <ExternalLink className="ml-auto h-3.5 w-3.5 opacity-50" />
      </a>
    );
  }

  if (!hasChildren) {
    return (
      <Link href={node.path} onClick={onNavigate} className={itemClass(active)}>
        {active && edge}
        <Icon className="h-[18px] w-[18px] shrink-0" />
        <span className="truncate">{t(node.titleKey)}</span>
      </Link>
    );
  }

  return (
    <div>
      <button type="button" onClick={() => setOpen((o) => !o)} className={itemClass(active && !open)}>
        {active && !open && edge}
        <Icon className={cn('h-[18px] w-[18px] shrink-0', active && 'text-brand-300')} />
        <span className={cn('truncate', active && 'text-white')}>{t(node.titleKey)}</span>
        <ChevronDown className={cn('ml-auto h-4 w-4 transition-transform', open && 'rotate-180')} />
      </button>
      {open && (
        <div className="ml-[1.35rem] mt-1 space-y-0.5 border-l border-white/[0.08] pl-3">
          {node.children.map((child) => {
            const on = pathname === child.path;
            return (
              <Link
                key={child.path + child.titleKey}
                href={child.path}
                onClick={onNavigate}
                className={cn(
                  'relative flex h-9 items-center rounded-lg px-2.5 text-[0.84rem] transition-colors',
                  on
                    ? 'bg-white/[0.07] font-semibold text-white before:absolute before:-left-[13px] before:top-1/2 before:h-4 before:w-[2px] before:-translate-y-1/2 before:rounded-full before:bg-brand-400'
                    : 'text-sidebar-muted hover:bg-white/[0.04] hover:text-white',
                )}
              >
                {t(child.titleKey)}
              </Link>
            );
          })}
        </div>
      )}
    </div>
  );
}

export function SidebarContent({ onNavigate }: { onNavigate?: () => void }) {
  const { t } = useI18n();
  const can = useCan();
  const session = useSession();
  const pathname = normalizePath(usePathname());
  const { data } = useSchool();
  const sections = buildNav(can);
  const school = data?.school;

  return (
    <div className="flex h-full flex-col text-sidebar-foreground">
      <Link href="/dashboard" onClick={onNavigate} className="flex items-center px-5 pb-4 pt-5" aria-label="Parvoz School">
        <ParvozWordmark size="md" sub="School" tone="onDark" />
      </Link>
      <div className="mx-3 flex items-center gap-3 rounded-2xl bg-white/[0.04] p-2.5 ring-1 ring-inset ring-white/[0.07]">
        <SchoolLogo school={school} className="h-10 w-10 shrink-0" />
        <div className="min-w-0 leading-tight">
          <p className="truncate text-[0.85rem] font-semibold text-white">{school?.name ?? '…'}</p>
          <p className="mt-0.5 truncate text-[0.72rem] text-sidebar-muted">
            {school ? `${school.city} · ${school.academicYear}` : t('shell.schoolChip')}
          </p>
        </div>
      </div>
      <ScrollArea className="mt-3 flex-1 px-3">
        <nav className="flex flex-col gap-5 py-2" aria-label="main">
          {sections.map((section) => (
            <div key={section.group} className="flex flex-col gap-0.5">
              <p className="mb-1 px-3 text-[0.66rem] font-semibold uppercase tracking-[0.16em] text-sidebar-muted/75">
                {t(`nav.groups.${section.group}`)}
              </p>
              {section.items.map((node) => (
                <NavLink key={node.path} node={node} pathname={pathname} onNavigate={onNavigate} />
              ))}
            </div>
          ))}
        </nav>
      </ScrollArea>
      {session && <UserMenu variant="sidebar" />}
    </div>
  );
}

/** Suzuvchi to'q ko'k shisha panel. Sahifadagi yagona `<aside>`. */
export function Sidebar() {
  return (
    <aside className="sticky top-0 hidden h-screen w-[284px] shrink-0 p-3 pr-0 lg:block no-print">
      <div className="glass-nav h-full overflow-hidden rounded-[22px]">
        <SidebarContent />
      </div>
    </aside>
  );
}
