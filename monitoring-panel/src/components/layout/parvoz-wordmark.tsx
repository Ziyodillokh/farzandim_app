import { cn } from '@/lib/utils';
import { ParvozLogo } from './parvoz-logo';

type Size = 'xs' | 'sm' | 'md' | 'lg' | 'xl';

const SIZES: Record<Size, { mark: string; text: string; gap: string }> = {
  xs: { mark: 'h-[18px] w-[18px] rounded-[5px]', text: 'text-[13px]', gap: 'gap-1.5' },
  sm: { mark: 'h-6 w-6 rounded-md', text: 'text-[15px]', gap: 'gap-2' },
  md: { mark: 'h-8 w-8 rounded-lg', text: 'text-[17px]', gap: 'gap-2.5' },
  lg: { mark: 'h-11 w-11 rounded-xl', text: 'text-[22px]', gap: 'gap-3' },
  xl: { mark: 'h-16 w-16 rounded-2xl', text: 'text-[34px]', gap: 'gap-4' },
};

/**
 * Parvoz brendi: belgi + "Parvoz" (Unbounded, saytdagidek) + ixtiyoriy kichik yozuv ("SCHOOL").
 * Sarlavha emas — `span` (sahifadagi `main h1` yagona bo'lib qoladi).
 */
export function ParvozWordmark({
  size = 'md',
  sub,
  tone = 'auto',
  className,
}: {
  size?: Size;
  sub?: string;
  tone?: 'auto' | 'onDark';
  className?: string;
}) {
  const s = SIZES[size];
  return (
    <span className={cn('inline-flex items-center', s.gap, className)}>
      <ParvozLogo decorative className={cn(s.mark, 'shadow-[0_6px_18px_-6px_rgba(60,130,255,0.65)]')} />
      <span className="flex flex-col leading-none">
        <span className={cn('font-display font-medium tracking-[0.01em]', s.text, tone === 'onDark' ? 'text-white' : 'text-foreground')}>Parvoz</span>
        {sub && (
          <span className={cn('mt-[0.35em] text-[0.62em] font-semibold uppercase tracking-[0.24em]', s.text, tone === 'onDark' ? 'text-brand-300' : 'text-primary')}>
            {sub}
          </span>
        )}
      </span>
    </span>
  );
}
