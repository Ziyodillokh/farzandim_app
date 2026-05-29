'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { ArrowLeft, Plus, Hash, MoreVertical } from 'lucide-react';
import { useChildren } from '@/hooks/useChildren';
import { PrimaryButton } from '@/components/widgets/primary-button';
import { ChildAvatar } from '@/components/widgets/child-avatar';
import { cn } from '@/lib/utils';
import type { Child } from '@/types/api.types';

/**
 * Children management — Flutter `children_management_screen.dart` ekvivalenti.
 *
 * Layout:
 *   - Header: Back + "Bolalar" sarlavha
 *   - List: ChildCard'lar (avatar, ism, yosh/hudud, connection badge, family code pill, action menu)
 *   - Empty: child_care icon + "Hali bola qo'shilmagan" + PrimaryButton
 *   - FAB: pastdan o'ngda "Bola qo'shish" (faqat list bor paytda)
 */
export default function ChildrenPage() {
  const router = useRouter();
  const { data: children, isLoading } = useChildren();

  return (
    <div className="gradient-bg min-h-screen">
      <div className="mx-auto max-w-2xl">
        {/* Header */}
        <Header onBack={() => router.back()} />

        {/* Content */}
        <div className="px-6">
          {isLoading ? (
            <ListSkeleton />
          ) : !children || children.length === 0 ? (
            <EmptyState />
          ) : (
            <ChildrenList items={children} />
          )}
        </div>
      </div>

      {/* FAB — faqat list bor paytda */}
      {children && children.length > 0 && (
        <Link
          href="/children/new"
          className="fixed bottom-6 right-6 z-20 flex h-14 items-center gap-2 rounded-full bg-primary pl-4 pr-5 text-background shadow-lg shadow-primary/30 transition-all hover:bg-[hsl(var(--primary-dark))]"
        >
          <Plus className="h-5 w-5" />
          <span className="text-[17px] font-semibold">Bola qo&apos;shish</span>
        </Link>
      )}
    </div>
  );
}

/* ════════════════════════ HEADER ════════════════════════ */

function Header({ onBack }: { onBack: () => void }) {
  return (
    <div className="flex items-center px-4 py-2">
      <button
        onClick={onBack}
        className="flex h-12 w-12 items-center justify-center rounded-full hover:bg-white/5"
        aria-label="Orqaga"
      >
        <ArrowLeft className="h-6 w-6 text-foreground" />
      </button>
      <div className="flex-1 text-center">
        <h1 className="text-[20px] font-semibold text-foreground">Bolalar</h1>
      </div>
      <div className="w-12" />
    </div>
  );
}

/* ════════════════════════ EMPTY STATE ════════════════════════ */

function EmptyState() {
  return (
    <div className="flex min-h-[60vh] items-center justify-center px-8">
      <div className="flex flex-col items-center">
        {/* child_care_outlined ikona — Lucide'da Baby */}
        <BabyIcon className="h-20 w-20 text-muted-foreground" />
        <div className="h-4" />
        <p className="text-center text-[18px] font-bold leading-snug text-foreground">
          Hali bola qo&apos;shilmagan
        </p>
        <div className="h-6" />
        <PrimaryButton
          href="/children/new"
          icon={<Plus className="h-5 w-5" />}
          expanded={false}
        >
          Bola qo&apos;shish
        </PrimaryButton>
      </div>
    </div>
  );
}

function BabyIcon({ className }: { className?: string }) {
  // Material child_care_outlined ikon stilini taqlid qilamiz
  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.5"
    >
      <circle cx="12" cy="12" r="10" />
      <circle cx="9" cy="10" r="1" fill="currentColor" />
      <circle cx="15" cy="10" r="1" fill="currentColor" />
      <path d="M9 15c0.5 1 1.5 1.5 3 1.5s2.5-0.5 3-1.5" strokeLinecap="round" />
    </svg>
  );
}

/* ════════════════════════ LIST ════════════════════════ */

function ChildrenList({ items }: { items: Child[] }) {
  return (
    <ul className="space-y-3 pb-28 pt-2">
      {items.map((c) => (
        <li key={c.id}>
          <ChildCard child={c} />
        </li>
      ))}
    </ul>
  );
}

function ChildCard({ child }: { child: Child }) {
  return (
    <Link
      href={`/children/${child.id}/edit`}
      className="flex items-start gap-4 rounded-2xl bg-[hsl(var(--card))] p-4 transition-colors hover:bg-[hsl(var(--surface-variant))]"
    >
      <ChildAvatar name={child.name} photoUrl={null} size={56} />

      <div className="min-w-0 flex-1">
        {/* Ism */}
        <p className="truncate text-[17px] font-bold text-foreground">
          {child.name}
        </p>

        {/* Yoshi va hududi */}
        <p className="mt-1 truncate text-[13px] text-muted-foreground">
          {child.age ?? '?'} yosh{child.region ? ` • ${child.region}` : ''}
        </p>

        {/* Connection badge */}
        <div className="mt-2">
          <ConnectionBadge isConnected={child.isConnected} />
        </div>

        {/* Family code pill */}
        <div className="mt-2">
          <FamilyCodePill code={child.familyCode} />
        </div>
      </div>

      {/* Action menu (vertical dots) */}
      <button
        onClick={(e) => {
          e.preventDefault();
          // TODO: popup menu (Tahrirlash / O'chirish)
        }}
        className="-m-2 flex h-10 w-10 items-center justify-center rounded-full hover:bg-white/5"
        aria-label="Boshqarish"
      >
        <MoreVertical className="h-5 w-5 text-foreground" />
      </button>
    </Link>
  );
}

/* ════════════════════════ BADGE + PILL ════════════════════════ */

function ConnectionBadge({ isConnected }: { isConnected: boolean }) {
  return (
    <span className="inline-flex items-center gap-1.5">
      <span
        className={cn(
          'inline-block h-2 w-2 rounded-full',
          isConnected
            ? 'bg-success shadow-[0_0_8px_2px_rgba(74,222,128,0.4)]'
            : 'bg-[hsl(var(--text-tertiary))]',
        )}
      />
      <span
        className={cn(
          'text-[13px] font-medium',
          isConnected ? 'text-success' : 'text-muted-foreground',
        )}
      >
        {isConnected ? 'Ulangan' : 'Ulanmagan'}
      </span>
    </span>
  );
}

function FamilyCodePill({ code }: { code: string }) {
  return (
    <span className="inline-flex items-center gap-1 rounded-full bg-primary px-2.5 py-1 text-background">
      <Hash className="h-3 w-3" strokeWidth={2.5} />
      <span className="font-mono text-[12px] font-bold tracking-wider">
        {code}
      </span>
    </span>
  );
}

/* ════════════════════════ SKELETON ════════════════════════ */

function ListSkeleton() {
  return (
    <ul className="space-y-3 pb-28 pt-2">
      {Array.from({ length: 3 }).map((_, i) => (
        <li key={i} className="h-32 animate-pulse rounded-2xl bg-[hsl(var(--card))]" />
      ))}
    </ul>
  );
}
