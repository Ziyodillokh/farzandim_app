'use client';

import { ChevronRight } from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';

export interface FilterOption {
  value: string;
  label: string;
}

/** users/payments sahifalaridagi FilterSelect bilan bir xil; mobilda to'liq kenglik. */
export function FilterSelect({
  value,
  onChange,
  options,
  ariaLabel,
}: {
  value: string;
  onChange: (v: string) => void;
  options: FilterOption[];
  ariaLabel: string;
}) {
  const current = options.find((o) => o.value === value) ?? options[0];
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button
          variant="outline"
          // Joriy qiymat ham o'qilsin (masalan, "Kategoriya: Barcha kategoriyalar").
          aria-label={`${ariaLabel}: ${current?.label ?? ''}`}
          className="w-full justify-between sm:w-auto sm:min-w-[170px] sm:max-w-[280px]"
        >
          <span className="truncate">{current?.label}</span>
          <ChevronRight className="rotate-90" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent className="max-h-80 min-w-[220px] overflow-y-auto">
        {options.map((opt) => (
          <DropdownMenuItem
            key={opt.value}
            onClick={() => onChange(opt.value)}
            className={value === opt.value ? 'font-semibold text-primary' : ''}
          >
            {opt.label}
          </DropdownMenuItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
