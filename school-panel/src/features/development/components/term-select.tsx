'use client';

import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { useI18n } from '@/i18n';
import { formatTerm } from '../lib/domains';

/** Chorak tanlovi (o'quvchilar soni bilan). */
export function TermSelect({ value, options, onChange }: { value: string | undefined; options: Array<{ key: string; n: number }> | undefined; onChange: (key: string) => void }) {
  const { t, formatNumber } = useI18n();
  if (!options?.length) return null;
  return (
    <Select value={value} onValueChange={onChange}>
      <SelectTrigger className="h-10 w-full sm:w-64" aria-label={t('development.term.label')}>
        <SelectValue placeholder={t('development.term.label')} />
      </SelectTrigger>
      <SelectContent>
        {options.map((o) => (
          <SelectItem key={o.key} value={o.key}>
            <span className="flex items-center gap-2">
              {formatTerm(o.key, t)}
              <span className="tabular-nums text-xs text-muted-foreground">n={formatNumber(o.n)}</span>
            </span>
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  );
}
