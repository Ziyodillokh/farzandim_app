'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

import { useCan, useSession } from '@/auth/use-session';
import { ScrollArea } from '@/components/ui/scroll-area';
import { useI18n } from '@/i18n';
import { normalizePath } from '@/lib/base-path';
import { cn } from '@/lib/utils';
import { buildNav, type NavNode } from './nav-items';
import { ParvozWordmark } from './parvoz-wordmark';
import { ScopeChip } from './scope-chip';
import { UserMenu } from './user-menu';

function isActive(pathname: string, href: string): boolean {
  return pathname === href || pathname.startsWith(`${href}/`);
}

function NavLink({ node, pathname, onNavigate }: { node: NavNode; pathname: string; onNavigate?: () => void }) {
  const { t } = useI18n();
  const Icon = node.icon;
  const active = isActive(pathname, node.path);
  return (
    <Link
      href={node.path}
      onClick={onNavigate}
      aria-current={active ? 'page' : undefined}
      className={cn(
        'group relative flex h-10 w-full items-center gap-3 rounded-xl px-3 text-[0.88rem] font-medium transition-all',
        active
          ? 'bg-gradient-to-r from-primary/35 to-primary/[0.06] text-white shadow-[0_8px_20px_-12px_hsl(var(--primary)/0.9)] ring-1 ring-inset ring-white/[0.08] [&>svg:first-of-type]:text-brand-300'
          : 'text-sidebar-muted hover:bg-white/[0.05] hover:text-white',
      )}
    >
      {active && <span className="absolute left-0 top-1/2 h-5 w-1 -translate-y-1/2 rounded-r-full bg-brand-400 shadow-[0_0_12px_rgba(80,138,255,0.9)]" />}
      <Icon className="h-[18px] w-[18px] shrink-0" />
      <span className="truncate">{t(node.titleKey)}</span>
    </Link>
  );
}

export function SidebarContent({ onNavigate }: { onNavigate?: () => void }) {
  const { t } = useI18n();
  const can = useCan();
  const session = useSession();
  const pathname = normalizePath(usePathname());
  const sections = buildNav(can);

  return (
    <div className="flex h-full flex-col text-sidebar-foreground">
      <Link href="/dashboard" onClick={onNavigate} className="flex items-center px-5 pb-4 pt-5" aria-label="Parvoz Monitoring">
        <ParvozWordmark size="md" sub="Monitoring" tone="onDark" />
      </Link>
      <ScopeChip />
      <ScrollArea className="mt-3 flex-1 px-3">
        <nav className="flex flex-col gap-5 py-2" aria-label="main">
          {sections.map((section) => (
            <div key={section.group} className="flex flex-col gap-0.5">
              <p className="mb-1 px-3 text-[0.66rem] font-semibold uppercase tracking-[0.16em] text-sidebar-muted/75">{t(`nav.groups.${section.group}`)}</p>
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
    <aside className="sticky top-0 hidden h-screen w-[272px] shrink-0 p-3 pr-0 lg:block no-print">
      <div className="glass-nav h-full overflow-hidden rounded-[22px]">
        <SidebarContent />
      </div>
    </aside>
  );
}
