'use client';

import Image from 'next/image';
import Link from 'next/link';
import { useState } from 'react';
import {
  Bell,
  Settings,
  Smartphone,
  Mic,
  Timer,
  MapPin,
  Calendar,
  Plus,
  ChevronLeft,
  ChevronRight,
} from 'lucide-react';
import { useChildren } from '@/hooks/useChildren';
import { PrimaryButton } from '@/components/widgets/primary-button';
import { QuickActionTile } from '@/components/widgets/quick-action-tile';
import { cn } from '@/lib/utils';
import type { Child } from '@/types/api.types';

/**
 * Dashboard ekran — Flutter `dashboard_screen.dart` 1:1 ekvivalenti.
 *
 * Conditional:
 *   - children.isEmpty → empty state (TopBar + center card + addButton + settings)
 *   - has children → glassmorphism layout (3 layer stack)
 *       Layer 1: scrollable kontent (ScreenTimeChart + QuickActions grid)
 *       Layer 2: top glass plate (TopBar + ChildPageView)
 *       Layer 3: bottom glass plate (Settings tugmasi)
 *
 * Web ekvivalenti: backdrop-blur + position:sticky.
 */
export default function DashboardPage() {
  const { data: children, isLoading } = useChildren();

  if (isLoading) return <DashboardSkeleton />;

  if (!children || children.length === 0) {
    return <EmptyState />;
  }

  return <DashboardContent items={children} />;
}

/* ════════════════════════ EMPTY STATE ════════════════════════ */

function EmptyState() {
  return (
    <div className="gradient-bg min-h-screen">
      <div className="mx-auto flex min-h-screen max-w-md flex-col px-6 pt-4">
        <TopBar unreadCount={0} />

        <div className="h-8" />

        {/* Empty state card — Flutter surface bg, radiusL */}
        <div className="flex min-h-[280px] flex-col items-center justify-center rounded-3xl bg-[hsl(var(--card))] px-8 py-8">
          <p className="text-center text-[17px] leading-relaxed text-foreground">
            Farzandingizni dastur orqali kuzatib borish uchun uni qo&apos;shing
          </p>
          <div className="h-6" />
          <PrimaryButton
            href="/children/new"
            icon={<Plus className="h-5 w-5" />}
            expanded={false}
          >
            Yangi bola qo&apos;shish
          </PrimaryButton>
        </div>

        <div className="flex-1" />
        <SettingsCircleButton />
        <div className="h-4" />
      </div>
    </div>
  );
}

/* ════════════════════════ HAS CHILDREN ════════════════════════ */

function DashboardContent({ items }: { items: Child[] }) {
  const [selectedIndex, setSelectedIndex] = useState(0);
  const child = items[Math.min(selectedIndex, items.length - 1)];

  return (
    <div className="gradient-bg relative min-h-screen">
      {/* Layer 2 (sticky top): TopBar + ChildPageView + glassmorphism */}
      <header className="sticky top-0 z-20 border-b border-white/[0.06] bg-background/20 backdrop-blur-2xl">
        <div className="mx-auto max-w-2xl px-6 py-4">
          <TopBar unreadCount={0} />
        </div>
        <div className="mx-auto max-w-2xl pb-4">
          <ChildPageView
            items={items}
            selectedIndex={selectedIndex}
            onSelect={setSelectedIndex}
          />
        </div>
      </header>

      {/* Layer 1: scrollable content */}
      <main className="mx-auto max-w-2xl px-6 py-6 pb-32">
        <ScreenTimeCard childId={child.id} />
        <div className="h-6" />
        <QuickActionsGrid childId={child.id} />
      </main>

      {/* Layer 3 (sticky bottom): Settings — glassmorphism */}
      <footer className="fixed bottom-0 left-0 right-0 z-20 border-t border-white/[0.06] bg-background/20 backdrop-blur-2xl">
        <div className="mx-auto flex max-w-2xl items-center justify-center py-4">
          <SettingsCircleButton />
        </div>
      </footer>
    </div>
  );
}

/* ════════════════════════ TOP BAR ════════════════════════ */

function TopBar({ unreadCount }: { unreadCount: number }) {
  return (
    <div className="flex items-center justify-between">
      <Image
        src="/assets/icons/parent_logo_icon.png"
        alt="Farzandim"
        width={64}
        height={64}
        priority
        className="object-contain"
      />
      <NotificationBell unreadCount={unreadCount} />
    </div>
  );
}

function NotificationBell({ unreadCount }: { unreadCount: number }) {
  return (
    <Link
      href="/notifications"
      className="relative flex h-12 w-12 items-center justify-center rounded-full bg-[hsl(var(--card))] transition-colors hover:bg-[hsl(var(--surface-variant))]"
    >
      <Bell className="h-6 w-6 text-foreground" strokeWidth={1.8} />
      {unreadCount > 0 && (
        <span className="absolute right-1.5 top-1.5 flex h-4 min-w-[16px] items-center justify-center rounded-full border-[1.5px] border-[hsl(var(--card))] bg-destructive px-1 text-[10px] font-bold text-white">
          {unreadCount > 9 ? '9+' : unreadCount}
        </span>
      )}
    </Link>
  );
}

/* ════════════════════════ CHILD PAGE VIEW (CAROUSEL) ════════════════════════ */

function ChildPageView({
  items,
  selectedIndex,
  onSelect,
}: {
  items: Child[];
  selectedIndex: number;
  onSelect: (i: number) => void;
}) {
  const child = items[selectedIndex];

  return (
    <div className="px-6">
      <div className="flex items-center gap-3">
        {/* Avatar */}
        <div className="flex h-16 w-16 items-center justify-center rounded-full bg-primary text-2xl font-bold text-background">
          {child.name[0]?.toUpperCase()}
        </div>

        {/* Name + status */}
        <div className="flex-1">
          <div className="flex items-center gap-2">
            <h2 className="text-xl font-semibold">{child.name}</h2>
            {items.length > 1 && (
              <div className="flex gap-1">
                {items.map((_, i) => (
                  <span
                    key={i}
                    className={cn(
                      'h-1.5 w-1.5 rounded-full transition-colors',
                      i === selectedIndex ? 'bg-primary' : 'bg-white/20',
                    )}
                  />
                ))}
              </div>
            )}
          </div>
          <p className="mt-0.5 text-sm text-muted-foreground">
            {child.isConnected ? 'Qurilma ulangan' : 'Qurilma ulanmagan'}
          </p>
        </div>

        {/* Carousel controls (>1 child) */}
        {items.length > 1 && (
          <div className="flex gap-1">
            <button
              onClick={() => onSelect(Math.max(0, selectedIndex - 1))}
              disabled={selectedIndex === 0}
              className="flex h-9 w-9 items-center justify-center rounded-full bg-[hsl(var(--card))] disabled:opacity-30"
            >
              <ChevronLeft className="h-4 w-4" />
            </button>
            <button
              onClick={() => onSelect(Math.min(items.length - 1, selectedIndex + 1))}
              disabled={selectedIndex === items.length - 1}
              className="flex h-9 w-9 items-center justify-center rounded-full bg-[hsl(var(--card))] disabled:opacity-30"
            >
              <ChevronRight className="h-4 w-4" />
            </button>
          </div>
        )}
      </div>
    </div>
  );
}

/* ════════════════════════ SCREEN TIME CHART ════════════════════════ */

function ScreenTimeCard({ childId: _childId }: { childId: string }) {
  // TODO: real chart with recharts
  return (
    <div className="rounded-3xl bg-[hsl(var(--card))] p-6">
      <p className="text-xs font-medium uppercase tracking-wider text-muted-foreground">
        Bugun ekran vaqti
      </p>
      <p className="mt-2 text-3xl font-bold">2 st 34 daq</p>
      <div className="mt-4 flex h-2 overflow-hidden rounded-full bg-white/5">
        <div className="bg-primary" style={{ width: '40%' }} />
        <div className="bg-[hsl(var(--secondary))]" style={{ width: '25%' }} />
        <div className="bg-warning" style={{ width: '15%' }} />
      </div>
      <div className="mt-3 flex gap-4 text-xs text-muted-foreground">
        <Legend color="bg-primary" label="Ta'lim" />
        <Legend color="bg-[hsl(var(--secondary))]" label="Aloqa" />
        <Legend color="bg-warning" label="O'yin" />
      </div>
    </div>
  );
}

function Legend({ color, label }: { color: string; label: string }) {
  return (
    <span className="flex items-center gap-1.5">
      <span className={cn('h-2 w-2 rounded-full', color)} />
      {label}
    </span>
  );
}

/* ════════════════════════ QUICK ACTIONS GRID ════════════════════════ */

function QuickActionsGrid({ childId }: { childId: string }) {
  return (
    <div className="grid grid-cols-2 gap-3">
      <QuickActionTile
        href={`/children/${childId}/device`}
        icon={<Smartphone className="h-5 w-5" />}
        label="Qurilma sozlamalari"
        accentClass="text-[hsl(var(--info))]"
      />
      <QuickActionTile
        href={`/children/${childId}/voice`}
        icon={<Mic className="h-5 w-5" />}
        label="Ovoz xabarlari"
        accentClass="text-primary"
      />
      <QuickActionTile
        href={`/children/${childId}/app-restrictions`}
        icon={<Timer className="h-5 w-5" />}
        label="Ilova cheklovlari"
        accentClass="text-warning"
      />
      <QuickActionTile
        href={`/children/${childId}/location`}
        icon={<MapPin className="h-5 w-5" />}
        label="Joylashuv"
        accentClass="text-success"
      />
      <QuickActionTile
        href={`/children/${childId}/schedules`}
        icon={<Calendar className="h-5 w-5" />}
        label="Jadvallar"
        accentClass="text-destructive"
      />
    </div>
  );
}

/* ════════════════════════ SETTINGS BUTTON ════════════════════════ */

function SettingsCircleButton() {
  return (
    <Link
      href="/settings"
      className="flex h-14 w-14 items-center justify-center rounded-full border border-border bg-transparent transition-colors hover:bg-[hsl(var(--card))]"
    >
      <Settings className="h-6 w-6" strokeWidth={1.8} />
    </Link>
  );
}

/* ════════════════════════ SKELETON ════════════════════════ */

function DashboardSkeleton() {
  return (
    <div className="gradient-bg min-h-screen">
      <div className="mx-auto max-w-2xl px-6 py-6 space-y-6">
        <div className="flex items-center justify-between">
          <div className="h-10 w-32 animate-pulse rounded bg-card" />
          <div className="h-12 w-12 animate-pulse rounded-full bg-card" />
        </div>
        <div className="h-20 animate-pulse rounded-3xl bg-card" />
        <div className="h-40 animate-pulse rounded-3xl bg-card" />
        <div className="grid grid-cols-2 gap-3">
          {Array.from({ length: 6 }).map((_, i) => (
            <div key={i} className="aspect-[1.1] animate-pulse rounded-2xl bg-card" />
          ))}
        </div>
      </div>
    </div>
  );
}
