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
import { ParvozLogo } from './parvoz-logo';
import { UserCard } from './user-card';

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
      'group relative flex h-10 w-full items-center gap-3 rounded-lg px-3 text-[0.9rem] font-medium transition-colors',
      on ? 'bg-sidebar-accent text-white' : 'text-sidebar-muted hover:bg-white/[0.04] hover:text-sidebar-foreground',
    );

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
        {active && <span className="absolute left-0 top-2 h-6 w-1 rounded-r-full bg-primary" />}
        <Icon className="h-[18px] w-[18px] shrink-0" />
        <span className="truncate">{t(node.titleKey)}</span>
      </Link>
    );
  }

  return (
    <div>
      <button type="button" onClick={() => setOpen((o) => !o)} className={itemClass(active && !open)}>
        {active && <span className="absolute left-0 top-2 h-6 w-1 rounded-r-full bg-primary" />}
        <Icon className="h-[18px] w-[18px] shrink-0" />
        <span className="truncate">{t(node.titleKey)}</span>
        <ChevronDown className={cn('ml-auto h-4 w-4 transition-transform', open && 'rotate-180')} />
      </button>
      {open && (
        <div className="ml-[1.35rem] mt-0.5 space-y-0.5 border-l border-sidebar-border pl-3">
          {node.children.map((child) => {
            const on = pathname === child.path;
            return (
              <Link
                key={child.path + child.titleKey}
                href={child.path}
                onClick={onNavigate}
                className={cn(
                  'flex h-9 items-center rounded-md px-2.5 text-[0.85rem] transition-colors',
                  on ? 'bg-sidebar-accent font-semibold text-white' : 'text-sidebar-muted hover:text-sidebar-foreground',
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

  return (
    <div className="flex h-full flex-col bg-sidebar text-sidebar-foreground">
      <Link href="/dashboard" onClick={onNavigate} className="flex items-center gap-3 px-5 pb-4 pt-5">
        <SchoolLogo school={data?.school} className="h-11 w-11" />
        <div className="min-w-0 leading-tight">
          <p className="truncate text-[0.95rem] font-semibold text-white">{data?.school.name ?? '…'}</p>
          <p className="mt-0.5 flex items-center gap-1.5 text-xs text-sidebar-muted">
            <ParvozLogo className="h-3.5 w-3.5 rounded" />
            Parvoz School
          </p>
        </div>
      </Link>
      <ScrollArea className="flex-1 px-3">
        <nav className="flex flex-col gap-5 py-2" aria-label="main">
          {sections.map((section) => (
            <div key={section.group} className="flex flex-col gap-0.5">
              <p className="mb-1 px-3 text-2xs font-semibold uppercase tracking-[0.14em] text-sidebar-muted/70">
                {t(`nav.groups.${section.group}`)}
              </p>
              {section.items.map((node) => (
                <NavLink key={node.path} node={node} pathname={pathname} onNavigate={onNavigate} />
              ))}
            </div>
          ))}
        </nav>
      </ScrollArea>
      {session && <UserCard />}
    </div>
  );
}

export function Sidebar() {
  return (
    <aside className="sticky top-0 hidden h-screen w-[272px] shrink-0 border-r border-sidebar-border lg:block no-print">
      <SidebarContent />
    </aside>
  );
}
