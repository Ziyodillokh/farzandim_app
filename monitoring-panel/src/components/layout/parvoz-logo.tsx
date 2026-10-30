import { withBase } from '@/lib/base-path';
import { cn } from '@/lib/utils';

/**
 * Parvoz logo belgisi — `public/icon.svg` (ilovadagi `parvoz_logo_mark.svg` bilan bir xil).
 * Rasm sifatida: har sahifa HTML'iga ~9 KB SVG yo'llari tushmaydi (bitta keshlangan fayl),
 * `useId` gidratatsiya farqi yo'q, chop etishda ham ko'rinadi.
 */
export function ParvozLogo({ className, title = 'Parvoz', decorative = false }: { className?: string; title?: string; decorative?: boolean }) {
  return (
    // eslint-disable-next-line @next/next/no-img-element -- basePath'li statik SVG
    <img
      src={withBase('/icon.svg')}
      alt={decorative ? '' : title}
      aria-hidden={decorative || undefined}
      draggable={false}
      className={cn('inline-block shrink-0 select-none rounded-[23.4%]', className)}
    />
  );
}
