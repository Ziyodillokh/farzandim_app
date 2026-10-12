import { CalendarClock, ClipboardList, Megaphone, PartyPopper, TreePalm, Users, type LucideIcon } from 'lucide-react';

import type { ReminderKind } from '@/data/contracts';
import { cn } from '@/lib/utils';

export const REMINDER_KINDS: readonly ReminderKind[] = ['MEETING', 'EXAM', 'EVENT', 'HOLIDAY', 'ANNOUNCEMENT', 'SCHEDULE_CHANGE'];

const KIND_STYLE: Record<ReminderKind, { icon: LucideIcon; tone: string }> = {
  MEETING: { icon: Users, tone: 'bg-primary/10 text-primary' },
  EXAM: { icon: ClipboardList, tone: 'bg-[hsl(var(--chart-5)/0.12)] text-[hsl(var(--chart-5))]' },
  EVENT: { icon: PartyPopper, tone: 'bg-[hsl(var(--chart-4)/0.12)] text-[hsl(var(--chart-4))]' },
  HOLIDAY: { icon: TreePalm, tone: 'bg-success/10 text-success' },
  ANNOUNCEMENT: { icon: Megaphone, tone: 'bg-info/10 text-info' },
  SCHEDULE_CHANGE: { icon: CalendarClock, tone: 'bg-warning/15 text-warning' },
};

/** Eslatma turi ikonkasi (rangli fon bilan). */
export function KindIcon({ kind, className }: { kind: ReminderKind; className?: string }) {
  const { icon: Icon, tone } = KIND_STYLE[kind];
  return (
    <span className={cn('flex h-10 w-10 shrink-0 items-center justify-center rounded-xl [&_svg]:size-5', tone, className)} aria-hidden>
      <Icon />
    </span>
  );
}
