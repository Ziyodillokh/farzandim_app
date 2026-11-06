import type { ReactNode } from 'react';

import { badgeVariants, type BadgeProps } from '@/components/ui/badge';
import { cn } from '@/lib/utils';

/**
 * Sarlavha (`h2`) yoki abzats ichidagi son nishoni. `Badge` — `div`, uni sarlavha/abzats ichiga qo'yish yaroqsiz HTML
 * bo'lgani uchun xuddi shu ko'rinishdagi `span`.
 */
export function CountChip({ variant = 'default', className, children }: { variant?: BadgeProps['variant']; className?: string; children: ReactNode }) {
  return <span className={cn(badgeVariants({ variant, size: 'sm' }), 'ml-2 align-middle tabular-nums', className)}>{children}</span>;
}
