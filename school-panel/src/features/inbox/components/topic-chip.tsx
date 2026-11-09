import { cn } from '@/lib/utils';

const TONES = {
  primary: 'bg-primary/10 text-primary ring-primary/20',
  warning: 'bg-amber-500/10 text-amber-700 ring-amber-500/25 dark:text-amber-300',
  success: 'bg-emerald-500/10 text-emerald-700 ring-emerald-500/25 dark:text-emerald-300',
  muted: 'bg-muted text-muted-foreground ring-border/60',
} as const;

/** Mavzu / holat yorlig'i (kichik, yumaloq). */
export function TopicChip({ label, tone = 'primary', className }: { label: string; tone?: keyof typeof TONES; className?: string }) {
  return (
    <span className={cn('inline-flex items-center rounded-full px-2 py-0.5 text-[0.7rem] font-semibold ring-1 ring-inset', TONES[tone], className)}>
      {label}
    </span>
  );
}
