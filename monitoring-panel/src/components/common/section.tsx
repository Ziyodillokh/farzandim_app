import Link from 'next/link';
import type { ReactNode } from 'react';
import { ArrowUpRight } from 'lucide-react';

import { Card } from '@/components/ui/card';
import { cn } from '@/lib/utils';

/**
 * Bo'lim kartasi: langar (`id`) bilan — dashboard ichki navigatsiyasi va
 * taqdimot shunga tayanadi. `href` bo'lsa — sarlavha yonida "Batafsil".
 */
export function Section({
  id,
  title,
  subtitle,
  icon,
  actions,
  href,
  hrefLabel,
  children,
  className,
  bodyClassName,
}: {
  id?: string;
  title: ReactNode;
  subtitle?: ReactNode;
  icon?: ReactNode;
  actions?: ReactNode;
  href?: string;
  hrefLabel?: string;
  children: ReactNode;
  className?: string;
  bodyClassName?: string;
}) {
  return (
    <Card id={id} className={cn('scroll-mt-24 overflow-hidden', className)}>
      <div className="flex flex-wrap items-start justify-between gap-3 border-b border-border/50 px-5 py-4 dark:border-white/[0.06]">
        <div className={cn('flex min-w-0 flex-1 basis-60 gap-3', subtitle ? 'items-start' : 'items-center')}>
          {icon && (
            <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary ring-1 ring-inset ring-primary/15 [&_svg]:size-[18px]">{icon}</span>
          )}
          <div className="min-w-0">
            <h2 className="text-[0.98rem] font-semibold tracking-[-0.005em]">{title}</h2>
            {subtitle && <p className="mt-0.5 text-[0.8rem] text-muted-foreground">{subtitle}</p>}
          </div>
        </div>
        <div className="flex shrink-0 items-center gap-2 no-print">
          {actions}
          {href && (
            <Link href={href} className="inline-flex h-8 items-center gap-1 rounded-lg px-2.5 text-[0.78rem] font-semibold text-primary transition-colors hover:bg-primary/[0.08]">
              {hrefLabel}
              <ArrowUpRight className="h-3.5 w-3.5" />
            </Link>
          )}
        </div>
      </div>
      <div className={cn('p-5', bodyClassName)}>{children}</div>
    </Card>
  );
}
