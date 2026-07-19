'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useState } from 'react';
import {
  LayoutDashboard,
  Users,
  Video,
  Headphones,
  BookOpen,
  FileText,
  Trophy,
  Shield,
  CreditCard,
  Bell,
  BarChart3,
  ScrollText,
  Settings,
  ChevronDown,
  LogOut,
  Sparkles,
  Tag,
  Receipt,
  FolderOpen,
} from 'lucide-react';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { cn, initials } from '@/lib/utils';
import { useAuthStore } from '@/stores/auth.store';
import { authApi } from '@/lib/api/admin.api';
import { useRouter } from 'next/navigation';

type IconType = typeof LayoutDashboard;

interface NavItem {
  label: string;
  href: string;
  icon: IconType;
}
interface NavGroup {
  label: string;
  icon: IconType;
  items: NavItem[];
}
type NavEntry = NavItem | NavGroup;

const isGroup = (e: NavEntry): e is NavGroup => 'items' in e;

const navigation: NavEntry[] = [
  { label: 'Dashboard', href: '/dashboard', icon: LayoutDashboard },
  { label: 'Foydalanuvchilar', href: '/users', icon: Users },
  {
    label: 'Kontentlar',
    icon: FolderOpen,
    items: [
      { label: 'Videolar', href: '/content/videos', icon: Video },
      { label: 'Audiokitoblar', href: '/content/audiobooks', icon: Headphones },
      { label: 'Kitoblar', href: '/content/books', icon: BookOpen },
      { label: 'Maqolalar', href: '/content/articles', icon: FileText },
      { label: 'Kategoriyalar', href: '/content/categories', icon: Tag },
    ],
  },
  { label: 'Konkurslar', href: '/olympiads', icon: Trophy },
  { label: 'Moderatorlar', href: '/moderators', icon: Shield },
  {
    label: 'Monetizatsiya',
    icon: CreditCard,
    items: [
      { label: 'Tariflar', href: '/monetization/plans', icon: Sparkles },
      { label: 'Promokodlar', href: '/monetization/promocodes', icon: Tag },
      { label: 'To‘lovlar', href: '/monetization/payments', icon: Receipt },
    ],
  },
  { label: 'Analitika', href: '/analytics', icon: BarChart3 },
  { label: 'Bildirishnomalar', href: '/notifications', icon: Bell },
  { label: 'Audit log', href: '/audit-log', icon: ScrollText },
  { label: 'Sozlamalar', href: '/settings', icon: Settings },
];

export function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();
  const user = useAuthStore((s) => s.user);
  const logout = useAuthStore((s) => s.logout);

  const handleLogout = async () => {
    try {
      await authApi.logout();
    } catch {
      /* network xato bo'lsa ham client'da logout */
    }
    logout();
    router.push('/login');
  };

  return (
    <aside className="sticky top-0 flex h-screen w-[260px] shrink-0 flex-col border-r border-sidebar-border bg-sidebar">
      {/* Brand */}
      <Link href="/dashboard" className="flex items-center gap-2.5 px-5 py-5">
        <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-gradient-to-br from-primary to-primary-glow shadow-primary-glow">
          <span className="text-base font-bold text-primary-foreground">F</span>
        </div>
        <div className="flex flex-col leading-none">
          <span className="text-base font-bold tracking-tight text-sidebar-foreground">Parvoz</span>
          <span className="text-2xs font-medium uppercase tracking-wider text-muted-foreground">Admin</span>
        </div>
      </Link>

      {/* Navigation */}
      <ScrollArea className="flex-1 px-3">
        <nav className="flex flex-col gap-0.5 py-2">
          {navigation.map((entry) =>
            isGroup(entry) ? (
              <NavGroupItem key={entry.label} group={entry} pathname={pathname} />
            ) : (
              <NavLinkItem key={entry.href} item={entry} active={pathname.startsWith(entry.href)} />
            ),
          )}
        </nav>
      </ScrollArea>

      {/* User card + Logout */}
      <div className="border-t border-sidebar-border p-3">
        <div className="flex items-center gap-3 rounded-xl bg-sidebar-accent/50 p-2.5">
          <Avatar className="h-9 w-9">
            <AvatarFallback className="bg-primary/15 text-xs">
              {initials(user?.name)}
            </AvatarFallback>
          </Avatar>
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-semibold text-sidebar-foreground">
              {user?.name || 'Admin'}
            </p>
            <p className="truncate text-xs text-muted-foreground">{user?.email || ''}</p>
          </div>
          <button
            onClick={handleLogout}
            className="flex h-9 w-9 items-center justify-center rounded-lg text-muted-foreground transition-colors hover:bg-destructive/10 hover:text-destructive"
            aria-label="Chiqish"
          >
            <LogOut className="h-4 w-4" />
          </button>
        </div>
      </div>
    </aside>
  );
}

/* ─── NavLinkItem ─── */

function NavLinkItem({ item, active }: { item: NavItem; active: boolean }) {
  const Icon = item.icon;
  return (
    <Link
      href={item.href}
      className={cn(
        'group relative flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors',
        active
          ? 'bg-primary text-primary-foreground shadow-soft'
          : 'text-sidebar-foreground hover:bg-sidebar-accent hover:text-sidebar-foreground',
      )}
    >
      <Icon className={cn('h-4 w-4 shrink-0', active ? 'text-primary-foreground' : 'text-muted-foreground group-hover:text-foreground')} />
      <span className="truncate">{item.label}</span>
    </Link>
  );
}

/* ─── NavGroupItem (collapsible) ─── */

function NavGroupItem({ group, pathname }: { group: NavGroup; pathname: string }) {
  const isAnyActive = group.items.some((i) => pathname.startsWith(i.href));
  const [open, setOpen] = useState(isAnyActive);
  const Icon = group.icon;

  return (
    <div className="flex flex-col">
      <button
        onClick={() => setOpen((v) => !v)}
        className={cn(
          'group flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors',
          isAnyActive
            ? 'text-sidebar-foreground'
            : 'text-sidebar-foreground hover:bg-sidebar-accent',
        )}
      >
        <Icon className="h-4 w-4 shrink-0 text-muted-foreground group-hover:text-foreground" />
        <span className="flex-1 truncate text-left">{group.label}</span>
        <ChevronDown
          className={cn(
            'h-4 w-4 text-muted-foreground transition-transform',
            open && 'rotate-180',
          )}
        />
      </button>
      {open && (
        <div className="ml-3 mt-0.5 flex flex-col gap-0.5 border-l border-sidebar-border pl-2">
          {group.items.map((item) => (
            <NavLinkItem key={item.href} item={item} active={pathname.startsWith(item.href)} />
          ))}
        </div>
      )}
    </div>
  );
}
