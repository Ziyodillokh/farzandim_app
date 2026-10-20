'use client';

import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { GraduationCap, User } from 'lucide-react';

import { StaffAvatar } from '@/components/common/staff-avatar';
import { useRouter } from 'next/navigation';
import { useEffect, useMemo, useState } from 'react';

import { ROUTES } from '@/auth/route-manifest';
import { useCan } from '@/auth/use-session';
import { Command, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList } from '@/components/ui/command';
import { Dialog, DialogContent, DialogTitle } from '@/components/ui/dialog';
import { api } from '@/data/api';
import { useI18n } from '@/i18n';
import { withBase } from '@/lib/base-path';
import { useDebounced } from '@/lib/use-debounced';

const SEARCH_MIN = 2;
const SEARCH_DEBOUNCE_MS = 150;

export function CommandPalette({ open, onOpenChange }: { open: boolean; onOpenChange: (open: boolean) => void }) {
  const { t } = useI18n();
  const router = useRouter();
  const can = useCan();
  const [query, setQuery] = useState('');

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        onOpenChange(!open);
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, onOpenChange]);

  const pages = useMemo(() => {
    const seen = new Set<string>();
    return ROUTES.filter((r) => !r.hidden && can(r.perm)).filter((r) => {
      const key = `${r.path}|${r.titleKey}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
  }, [can]);

  const term = useDebounced(query.trim(), SEARCH_DEBOUNCE_MS);
  const searchable = open && term.length >= SEARCH_MIN;
  const { data } = useQuery({
    queryKey: ['search', term],
    queryFn: () => api.search.query(term),
    enabled: searchable,
    placeholderData: keepPreviousData,
    staleTime: 30_000,
  });
  // Qisqa so'rovda oldingi natija ko'rsatilmaydi.
  const results = searchable ? data : undefined;

  const go = (href: string, external = false) => {
    onOpenChange(false);
    setQuery('');
    if (external) window.open(withBase(`${href}/`), '_blank');
    else router.push(href);
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="overflow-hidden p-0 sm:max-w-xl">
        <DialogTitle className="sr-only">{t('shell.searchHint')}</DialogTitle>
        <Command shouldFilter={false}>
          <CommandInput value={query} onValueChange={setQuery} placeholder={t('shell.searchHint')} />
          <CommandList>
            <CommandEmpty>{t('shell.commandEmpty')}</CommandEmpty>
            {results && results.students.length > 0 && (
              <CommandGroup heading={t('shell.commandStudents')}>
                {results.students.map((s) => (
                  <CommandItem key={s.id} value={`stu-${s.id}`} onSelect={() => go(`/students/view?id=${s.id}`)}>
                    <User />
                    <span className="flex-1">{s.name}</span>
                    <span className="text-xs text-muted-foreground">
                      {s.className} · {s.studentCode}
                    </span>
                  </CommandItem>
                ))}
              </CommandGroup>
            )}
            {results && results.classes.length > 0 && (
              <CommandGroup heading={t('shell.commandClasses')}>
                {results.classes.map((c) => (
                  <CommandItem key={c.id} value={`cls-${c.id}`} onSelect={() => go(`/classes/view?id=${c.id}`)}>
                    <GraduationCap />
                    {c.name}
                  </CommandItem>
                ))}
              </CommandGroup>
            )}
            {results && results.staff.length > 0 && (
              <CommandGroup heading={t('shell.commandStaff')}>
                {results.staff.map((s) => (
                  <CommandItem key={s.id} value={`stf-${s.id}`} onSelect={() => go('/staff')}>
                    <StaffAvatar staffId={s.id} name={s.name} size="xs" />
                    <span className="flex-1">{s.name}</span>
                    <span className="text-xs text-muted-foreground">{s.position}</span>
                  </CommandItem>
                ))}
              </CommandGroup>
            )}
            <CommandGroup heading={t('shell.commandPages')}>
              {pages
                .filter((p) => !query || t(p.titleKey).toLowerCase().includes(query.toLowerCase()))
                .map((p) => {
                  const Icon = p.icon;
                  return (
                    <CommandItem key={`${p.path}-${p.titleKey}`} value={`page-${p.path}-${p.titleKey}`} onSelect={() => go(p.path, p.external)}>
                      <Icon />
                      {t(p.titleKey)}
                    </CommandItem>
                  );
                })}
            </CommandGroup>
          </CommandList>
        </Command>
      </DialogContent>
    </Dialog>
  );
}
