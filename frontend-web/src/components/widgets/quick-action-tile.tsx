'use client';

import Link from 'next/link';
import type { ReactNode } from 'react';
import { cn } from '@/lib/utils';

/**
 * QuickActionTile — Flutter `QuickActionTile` ekvivalenti.
 *
 * Square card (aspectRatio 1.1), ikonka pastda, label tepada.
 * Accent rangi har xil (info/primary/warning/success/error).
 */
interface Props {
  href: string;
  icon: ReactNode;
  label: string;
  accentClass: string; // tailwind text class
}

export function QuickActionTile({ href, icon, label, accentClass }: Props) {
  return (
    <Link
      href={href}
      className="group relative flex aspect-[1.1] flex-col justify-between rounded-2xl border border-border bg-[hsl(var(--card))] p-4 transition-all hover:border-primary/40 hover:bg-[hsl(var(--surface-variant))]"
    >
      <div className={cn('flex h-11 w-11 items-center justify-center rounded-xl bg-white/5', accentClass)}>
        {icon}
      </div>
      <div className="text-[15px] font-medium leading-snug text-foreground">
        {label}
      </div>
    </Link>
  );
}
