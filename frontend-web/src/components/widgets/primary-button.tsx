'use client';

import Link from 'next/link';
import { Loader2 } from 'lucide-react';
import { cn } from '@/lib/utils';
import { forwardRef, type ButtonHTMLAttributes, type ReactNode } from 'react';

/**
 * PrimaryButton — Flutter `primary_button.dart` 1:1 ekvivalenti.
 *
 * Parametrlar (Flutter PrimaryButton bilan bir xil):
 *   - label/children: tugma matni
 *   - icon: matn chap tomonidagi ikonka
 *   - isLoading: spinner + tap block
 *   - expanded: true (default) full width, false shrink-wrap
 *   - href: agar Link sifatida ishlatilsa
 *
 * Stil:
 *   - 60px balandlik (Flutter buttonHeight)
 *   - rounded-full (Flutter radiusPill = 999)
 *   - bg-primary (#C5F562 lime green)
 *   - text qora #0A0A12, weight 600, 17px
 *   - disabled: bg surface-variant, text tertiary
 */

interface BaseProps {
  icon?: ReactNode;
  isLoading?: boolean;
  expanded?: boolean;
  children: ReactNode;
}

interface ButtonProps extends BaseProps, Omit<ButtonHTMLAttributes<HTMLButtonElement>, 'children'> {
  href?: undefined;
}

interface LinkProps extends BaseProps {
  href: string;
  onClick?: undefined;
  disabled?: undefined;
  type?: undefined;
}

type Props = ButtonProps | LinkProps;

export const PrimaryButton = forwardRef<HTMLButtonElement | HTMLAnchorElement, Props>(
  function PrimaryButton({ children, icon, isLoading = false, expanded = true, className, ...rest }, ref) {
    const isDisabled = 'disabled' in rest ? rest.disabled : false;

    const content = isLoading ? (
      <Loader2 className="h-4 w-4 animate-spin text-background" strokeWidth={2.5} />
    ) : icon ? (
      <span className="flex items-center gap-2">
        <span className="flex h-5 w-5 items-center justify-center">{icon}</span>
        <span>{children}</span>
      </span>
    ) : (
      children
    );

    const classes = cn(
      'inline-flex h-[60px] items-center justify-center rounded-full px-6 text-[17px] font-semibold leading-none transition-colors',
      'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background',
      expanded ? 'w-full' : 'w-auto',
      isDisabled
        ? 'cursor-not-allowed bg-[hsl(var(--surface-variant))] text-[hsl(var(--text-tertiary))]'
        : 'bg-primary text-background hover:bg-[hsl(var(--primary-dark))]',
      className,
    );

    if ('href' in rest && rest.href) {
      return (
        <Link
          ref={ref as React.Ref<HTMLAnchorElement>}
          href={rest.href}
          className={classes}
        >
          {content}
        </Link>
      );
    }

    const { href: _href, ...buttonRest } = rest as ButtonProps;
    return (
      <button
        ref={ref as React.Ref<HTMLButtonElement>}
        className={classes}
        disabled={isDisabled || isLoading}
        {...buttonRest}
      >
        {content}
      </button>
    );
  },
);
