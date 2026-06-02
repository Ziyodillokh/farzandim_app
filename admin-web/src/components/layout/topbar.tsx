'use client';

import { Bell, Search, Command as CmdIcon } from 'lucide-react';
import { usePathname } from 'next/navigation';
import { ThemeToggle } from './theme-toggle';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';

const titles: Record<string, string> = {
  '/dashboard': 'Dashboard',
  '/users': 'Foydalanuvchilar',
  '/content/videos': 'Videolar',
  '/content/audiobooks': 'Audiokitoblar',
  '/content/books': 'Kitoblar',
  '/content/categories': 'Kategoriyalar',
  '/olympiads': 'Konkurslar',
  '/moderators': 'Moderatorlar',
  '/monetization/plans': 'Tariflar',
  '/monetization/promocodes': 'Promokodlar',
  '/monetization/payments': "To'lovlar",
  '/analytics': 'Analitika',
  '/notifications': 'Bildirishnomalar',
  '/audit-log': 'Audit log',
  '/settings': 'Sozlamalar',
};

export function Topbar() {
  const pathname = usePathname();
  const title =
    titles[pathname] ||
    Object.entries(titles).find(([k]) => pathname.startsWith(k))?.[1] ||
    'Admin';

  return (
    <header className="sticky top-0 z-30 flex h-16 items-center gap-4 border-b border-border bg-background/80 px-6 backdrop-blur-md">
      {/* Page title */}
      <div className="flex flex-col">
        <h1 className="text-base font-bold leading-none">{title}</h1>
      </div>

      {/* Search (center, hidden on small) */}
      <div className="ml-auto hidden md:block md:flex-1 md:max-w-md">
        <Input
          icon={<Search />}
          endIcon={
            <kbd className="hidden h-5 select-none items-center gap-1 rounded border border-border bg-muted px-1.5 font-mono text-[10px] font-medium text-muted-foreground sm:inline-flex">
              <CmdIcon className="h-3 w-3" /> K
            </kbd>
          }
          placeholder="Qidiruv... (⌘ K)"
          className="h-9 rounded-full bg-muted/50"
        />
      </div>

      {/* Right actions */}
      <div className="ml-auto flex items-center gap-2 md:ml-0">
        <Button
          variant="outline"
          size="icon"
          aria-label="Bildirishnomalar"
          className="relative rounded-full"
        >
          <Bell className="h-4 w-4" />
          <span className="absolute right-2 top-2 h-2 w-2 rounded-full bg-destructive" />
        </Button>
        <ThemeToggle />
      </div>
    </header>
  );
}
