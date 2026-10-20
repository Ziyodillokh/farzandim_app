import * as React from 'react';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/utils';

const badgeVariants = cva(
  'inline-flex items-center gap-1 rounded-full border px-2.5 py-0.5 text-xs font-semibold transition-colors focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2',
  {
    variants: {
      variant: {
        default: 'border-transparent bg-primary/10 text-primary ring-1 ring-inset ring-primary/15',
        secondary: 'border-transparent bg-secondary text-secondary-foreground',
        destructive: 'border-transparent bg-destructive/10 text-destructive ring-1 ring-inset ring-destructive/15',
        success: 'border-transparent bg-success/10 text-success ring-1 ring-inset ring-success/15',
        warning: 'border-transparent bg-warning/10 text-warning ring-1 ring-inset ring-warning/15',
        info: 'border-transparent bg-info/10 text-info ring-1 ring-inset ring-info/15',
        outline: 'border-border/70 bg-white/50 text-foreground dark:bg-white/[0.03]',
      },
      size: {
        default: 'text-xs',
        sm: 'text-2xs px-2 py-0.5',
      },
    },
    defaultVariants: { variant: 'default', size: 'default' },
  },
);

export interface BadgeProps
  extends React.HTMLAttributes<HTMLDivElement>,
    VariantProps<typeof badgeVariants> {}

function Badge({ className, variant, size, ...props }: BadgeProps) {
  return <div className={cn(badgeVariants({ variant, size }), className)} {...props} />;
}

export { Badge, badgeVariants };
