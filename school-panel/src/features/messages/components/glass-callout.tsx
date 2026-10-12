import type { ReactNode } from 'react';

import { Card } from '@/components/ui/card';
import { cn } from '@/lib/utils';
import { BRAND_GLOW, ICON_TONES } from '../styles';

/** Shisha "eslatma" bloki: ikonka plitkasi + sarlavha + matn (moliyaviy chegara, maxfiylik). */
export function GlassCallout({ icon, title, children, className }: { icon: ReactNode; title?: string; children: ReactNode; className?: string }) {
  return (
    <Card role="note" className={cn('relative overflow-hidden animate-fade-in', className)}>
      <div aria-hidden className={BRAND_GLOW} />
      <div className={cn('relative flex gap-4 p-4', !title && 'items-center')}>
        <span className={cn('flex h-10 w-10 shrink-0 items-center justify-center rounded-xl [&_svg]:size-5', ICON_TONES.primary)}>{icon}</span>
        <div className="min-w-0">
          {title && <p className="text-sm font-semibold">{title}</p>}
          <div className={cn('text-sm leading-relaxed text-muted-foreground', title && 'mt-0.5')}>{children}</div>
        </div>
      </div>
    </Card>
  );
}
