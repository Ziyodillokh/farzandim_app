import { CalendarClock, ClipboardList, Megaphone, PartyPopper, TreePalm, Users, type LucideIcon } from 'lucide-react';

import type { ReminderKind } from '@/data/contracts';
import { ICON_TONES } from '@/features/messages/styles';
import { cn } from '@/lib/utils';

export const REMINDER_KINDS: readonly ReminderKind[] = ['MEETING', 'EXAM', 'EVENT', 'HOLIDAY', 'ANNOUNCEMENT', 'SCHEDULE_CHANGE'];

const KIND_STYLE: Record<ReminderKind, { icon: LucideIcon; tone: string }> = {
  MEETING: { icon: Users, tone: ICON_TONES.primary },
  EXAM: { icon: ClipboardList, tone: ICON_TONES.sky },
  EVENT: { icon: PartyPopper, tone: ICON_TONES.cyan },
  HOLIDAY: { icon: TreePalm, tone: ICON_TONES.success },
  ANNOUNCEMENT: { icon: Megaphone, tone: 'bg-blue-500/10 text-blue-600 ring-1 ring-inset ring-blue-500/20 dark:text-blue-300' },
  SCHEDULE_CHANGE: { icon: CalendarClock, tone: ICON_TONES.warning },
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
