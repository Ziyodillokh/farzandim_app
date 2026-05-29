'use client';

import Link from 'next/link';
import { Bell, Settings } from 'lucide-react';
import { useAuthStore } from '@/stores/auth.store';

export function DashboardHeader() {
  const user = useAuthStore((s) => s.user);

  return (
    <header className="sticky top-0 z-30 border-b border-border bg-background/80 backdrop-blur-md">
      <div className="container flex h-16 items-center justify-between">
        {/* Logo */}
        <Link href="/dashboard" className="flex items-center gap-2">
          <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-primary/10">
            <span className="text-lg font-bold text-primary">F</span>
          </div>
          <span className="font-semibold">Farzandim</span>
        </Link>

        {/* Right: notifications + user */}
        <div className="flex items-center gap-2">
          <Link
            href="/notifications"
            className="flex h-10 w-10 items-center justify-center rounded-full border border-border bg-card transition-colors hover:bg-accent"
          >
            <Bell className="h-5 w-5" />
          </Link>
          <Link
            href="/settings"
            className="flex h-10 items-center gap-3 rounded-full border border-border bg-card pl-1 pr-4 transition-colors hover:bg-accent"
          >
            <div className="flex h-8 w-8 items-center justify-center rounded-full bg-primary text-sm font-semibold text-primary-foreground">
              {user?.name?.[0]?.toUpperCase() || '?'}
            </div>
            <span className="hidden text-sm font-medium sm:inline">
              {user?.name || 'Foydalanuvchi'}
            </span>
            <Settings className="h-4 w-4 text-muted-foreground" />
          </Link>
        </div>
      </div>
    </header>
  );
}
