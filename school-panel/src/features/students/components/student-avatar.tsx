import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import type { Gender } from '@/data/contracts';
import { cn, initials } from '@/lib/utils';

type Size = 'sm' | 'md' | 'lg';

const SIZES: Record<Size, string> = {
  sm: 'h-8 w-8 text-[0.65rem]',
  md: 'h-9 w-9 text-xs',
  lg: 'h-14 w-14 rounded-2xl text-base',
};

/** Jins bo'yicha faqat ko'k/osmon tuslari (brend palitrasi). */
const TONES: Record<Gender, string> = {
  MALE: 'bg-primary/10 text-primary ring-primary/15',
  FEMALE: 'bg-sky-500/10 text-sky-700 ring-sky-500/20 dark:text-sky-300',
};

/** O'quvchi bosh harflari avatari (o'quvchilarda rasm saqlanmaydi). */
export function StudentAvatar({ name, gender, size = 'md', className }: { name: string; gender: Gender; size?: Size; className?: string }) {
  return (
    <Avatar className={cn(SIZES[size], className)}>
      <AvatarFallback className={cn('font-semibold ring-1 ring-inset', size === 'lg' && 'rounded-2xl font-display', TONES[gender])}>
        {initials(name)}
      </AvatarFallback>
    </Avatar>
  );
}
