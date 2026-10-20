'use client';

import { Check, Search, X } from 'lucide-react';
import { useState } from 'react';

import { LinkBadge } from '@/components/common/status-badges';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { Skeleton } from '@/components/ui/skeleton';
import { useI18n } from '@/i18n';
import { useDebounced } from '@/lib/use-debounced';
import { cn } from '@/lib/utils';
import { useGuardianSearch } from '../hooks';
import { INNER_TILE } from '../styles';

/** Aniq ota-onalarni qidirib tanlash (sinf rahbari — faqat o'z sinfi ota-onalari). */
export function GuardianPicker({
  value,
  onChange,
  knownNames,
}: {
  value: string[];
  onChange: (next: string[]) => void;
  /** Tahrirlanayotgan qoralamadagi tanlanganlar nomi (qidiruv natijasida bo'lmasa ham). */
  knownNames?: Record<string, string>;
}) {
  const { t } = useI18n();
  const [search, setSearch] = useState('');
  const debounced = useDebounced(search);
  const results = useGuardianSearch(debounced);
  const [names, setNames] = useState<Record<string, string>>(knownNames ?? {});
  const selected = new Set(value);

  const toggle = (id: string, name: string) => {
    setNames((prev) => ({ ...prev, [id]: name }));
    onChange(selected.has(id) ? value.filter((v) => v !== id) : [...value, id]);
  };

  return (
    <div className="space-y-3">
      {value.length > 0 ? (
        <div className="flex flex-wrap gap-1.5">
          {value.map((id) => (
            <Badge key={id} variant="default" className="gap-1 py-1 pl-2.5 pr-1">
              {names[id] ?? knownNames?.[id] ?? id}
              <button type="button" onClick={() => onChange(value.filter((v) => v !== id))} className="rounded-full p-0.5 hover:bg-primary/15" aria-label={t('messages.audience.remove')}>
                <X className="h-3 w-3" />
              </button>
            </Badge>
          ))}
        </div>
      ) : (
        <p className="text-xs text-muted-foreground">{t('messages.audience.pickHint')}</p>
      )}
      <Input icon={<Search />} value={search} onChange={(e) => setSearch(e.target.value)} placeholder={t('messages.audience.searchGuardians')} aria-label={t('messages.audience.searchGuardians')} />
      <div className={cn(INNER_TILE, 'max-h-72 space-y-0.5 overflow-y-auto p-1.5')}>
        {results.isLoading && !results.data && Array.from({ length: 4 }).map((_, i) => <Skeleton key={i} className="h-12 w-full rounded-lg" />)}
        {results.data?.items.length === 0 && <p className="py-6 text-center text-sm text-muted-foreground">{t('messages.audience.noGuardians')}</p>}
        {results.data?.items.map((g) => {
          const on = selected.has(g.id);
          return (
            <button
              key={g.id}
              type="button"
              aria-pressed={on}
              onClick={() => toggle(g.id, g.fullName)}
              className={cn('flex w-full items-center gap-3 rounded-lg px-2.5 py-2 text-left transition-colors', on ? 'bg-primary/[0.09] dark:bg-primary/[0.14]' : 'hover:bg-primary/[0.05]')}
            >
              <span className={cn('flex h-5 w-5 shrink-0 items-center justify-center rounded-md border border-input', on && 'border-transparent bg-brand-gradient text-white')}>
                {on && <Check className="h-3.5 w-3.5" strokeWidth={3} />}
              </span>
              <span className="min-w-0 flex-1">
                <span className="block truncate text-sm font-medium">{g.fullName}</span>
                <span className="block truncate text-2xs text-muted-foreground">
                  {g.children.map((c) => `${c.name} (${c.className})`).join(', ')} · {g.phone}
                </span>
              </span>
              <span className="hidden shrink-0 sm:block">
                <LinkBadge status={g.linkStatus} />
              </span>
            </button>
          );
        })}
      </div>
    </div>
  );
}
