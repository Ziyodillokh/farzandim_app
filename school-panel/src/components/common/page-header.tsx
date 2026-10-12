import { ArrowLeft } from 'lucide-react';
import Link from 'next/link';
import type { ReactNode } from 'react';

import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';

export function PageHeader({
  title,
  subtitle,
  actions,
  backHref,
  backLabel,
  badge,
  className,
}: {
  title: ReactNode;
  subtitle?: ReactNode;
  actions?: ReactNode;
  backHref?: string;
  backLabel?: string;
  badge?: ReactNode;
  className?: string;
}) {
  return (
    <div className={cn('mb-6 flex flex-wrap items-end justify-between gap-4 animate-fade-in', className)}>
      <div className="min-w-0">
        {backHref && (
          <Button asChild variant="ghost" size="sm" className="-ml-2 mb-2 h-8 text-muted-foreground no-print">
            <Link href={backHref}>
              <ArrowLeft />
              {backLabel}
            </Link>
          </Button>
        )}
        <div className="flex flex-wrap items-center gap-3">
          <h1 className="font-display text-2xl font-semibold tracking-tight md:text-[1.7rem]">{title}</h1>
          {badge}
        </div>
        {subtitle && <p className="mt-1.5 max-w-3xl text-sm text-muted-foreground">{subtitle}</p>}
      </div>
      {actions && <div className="flex flex-wrap items-center gap-2 no-print">{actions}</div>}
    </div>
  );
}
