'use client';

import { Search, X } from 'lucide-react';
import { useEffect, useState, type ReactNode } from 'react';

import { Input } from '@/components/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { useI18n } from '@/i18n';
import { useDebounced } from '@/lib/use-debounced';
import { cn } from '@/lib/utils';

export function Toolbar({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={cn('mb-4 flex flex-wrap items-center gap-2 no-print', className)}>{children}</div>;
}

/** Qidiruv maydoni — 250 ms kechikish bilan `onChange`. */
export function SearchInput({
  value,
  onChange,
  placeholder,
  className,
}: {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  className?: string;
}) {
  const { t } = useI18n();
  const [draft, setDraft] = useState(value);
  const debounced = useDebounced(draft);

  useEffect(() => {
    if (debounced !== value) onChange(debounced);
  }, [debounced, onChange, value]);

  useEffect(() => {
    setDraft(value);
  }, [value]);

  return (
    <div className={cn('relative w-full sm:w-72', className)}>
      <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
      <Input
        value={draft}
        onChange={(e) => setDraft(e.target.value)}
        placeholder={placeholder ?? t('common.searchPlaceholder')}
        className="pl-9 pr-8"
        aria-label={t('common.search')}
      />
      {draft && (
        <button
          type="button"
          onClick={() => setDraft('')}
          className="absolute right-2.5 top-1/2 -translate-y-1/2 rounded p-0.5 text-muted-foreground hover:text-foreground"
          aria-label={t('common.close')}
        >
          <X className="h-3.5 w-3.5" />
        </button>
      )}
    </div>
  );
}

export type Option = { value: string; label: string };
export const ALL = '__all__';

/** Filtr tanlovi — "Barchasi" bo'lsa `undefined`. */
export function FilterSelect({
  value,
  onChange,
  options,
  placeholder,
  allLabel,
  className,
}: {
  value: string | undefined;
  onChange: (value: string | undefined) => void;
  options: Option[];
  placeholder?: string;
  allLabel?: string;
  className?: string;
}) {
  const { t } = useI18n();
  return (
    <Select value={value ?? ALL} onValueChange={(v) => onChange(v === ALL ? undefined : v)}>
      <SelectTrigger className={cn('w-full sm:w-48', className)}>
        <SelectValue placeholder={placeholder} />
      </SelectTrigger>
      <SelectContent>
        <SelectItem value={ALL}>{allLabel ?? t('common.all')}</SelectItem>
        {options.map((o) => (
          <SelectItem key={o.value} value={o.value}>
            {o.label}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  );
}
