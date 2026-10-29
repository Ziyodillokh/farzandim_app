import * as React from 'react';
import { Slot } from '@radix-ui/react-slot';
import { cva, type VariantProps } from 'class-variance-authority';
import { Loader2 } from 'lucide-react';
import { cn } from '@/lib/utils';

const buttonVariants = cva(
  'inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-xl text-sm font-semibold transition-all focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background disabled:pointer-events-none disabled:opacity-50 [&_svg]:size-4 [&_svg]:shrink-0',
  {
    variants: {
      variant: {
        default:
          'bg-brand-gradient text-white shadow-[inset_0_1px_0_hsl(0_0%_100%/0.22),0_8px_20px_-8px_hsl(var(--primary)/0.6)] hover:brightness-110 hover:shadow-[inset_0_1px_0_hsl(0_0%_100%/0.22),0_10px_24px_-8px_hsl(var(--primary)/0.7)] active:scale-[0.98]',
        destructive:
          'bg-destructive text-destructive-foreground shadow-soft hover:bg-destructive/90 active:scale-[0.98]',
        outline:
          'border border-border/70 bg-white/70 text-foreground shadow-soft hover:border-primary/40 hover:bg-white dark:bg-white/[0.04] dark:hover:bg-white/[0.08]',
        secondary:
          'bg-secondary/80 text-secondary-foreground hover:bg-secondary',
        ghost: 'hover:bg-primary/[0.07] hover:text-foreground dark:hover:bg-white/[0.06]',
        link: 'text-primary underline-offset-4 hover:underline',
        soft: 'bg-primary/10 text-primary hover:bg-primary/15 active:scale-[0.98]',
      },
      size: {
        default: 'h-10 px-4 py-2',
        sm: 'h-9 rounded-lg px-3 text-xs',
        lg: 'h-11 rounded-xl px-6 text-base',
        xl: 'h-12 rounded-2xl px-8 text-base',
        icon: 'h-10 w-10',
        'icon-sm': 'h-8 w-8 [&_svg]:size-3.5',
      },
    },
    defaultVariants: { variant: 'default', size: 'default' },
  },
);

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean;
  loading?: boolean;
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, loading, children, disabled, ...props }, ref) => {
    // Slot faqat bitta bola element qabul qiladi — asChild'da spinner qo'shilmaydi.
    if (asChild) {
      return (
        <Slot className={cn(buttonVariants({ variant, size, className }))} ref={ref} {...props}>
          {children}
        </Slot>
      );
    }
    return (
      <button className={cn(buttonVariants({ variant, size, className }))} ref={ref} disabled={disabled || loading} {...props}>
        {loading ? <Loader2 className="animate-spin" /> : null}
        {children}
      </button>
    );
  },
);
Button.displayName = 'Button';

export { Button, buttonVariants };
