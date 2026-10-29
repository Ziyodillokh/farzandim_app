'use client';

import { MapPin } from 'lucide-react';
import { useRouter } from 'next/navigation';
import { useEffect } from 'react';

import { useCan } from '@/auth/use-session';
import { ROUTES } from '@/auth/route-manifest';
import { Command, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList } from '@/components/ui/command';
import { Dialog, DialogContent, DialogTitle } from '@/components/ui/dialog';
import { REGIONS } from '@/data/reference/regions';
import { useI18n } from '@/i18n';

/** Global qidiruv (⌘K): sahifalar va hududlar. */
export function CommandPalette({ open, onOpenChange }: { open: boolean; onOpenChange: (open: boolean) => void }) {
  const { t, locale } = useI18n();
  const can = useCan();
  const router = useRouter();

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

  const go = (path: string) => {
    onOpenChange(false);
    router.push(path);
  };
  const pages = ROUTES.filter((r) => !r.hidden && can(r.perm));
  const canRegions = can('regions.view');

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="overflow-hidden p-0 sm:max-w-lg">
        <DialogTitle className="sr-only">{t('shell.searchHint')}</DialogTitle>
        <Command>
          <CommandInput placeholder={t('shell.searchHint')} />
          <CommandList>
            <CommandEmpty>{t('shell.commandEmpty')}</CommandEmpty>
            <CommandGroup heading={t('shell.commandPages')}>
              {pages.map((r) => {
                const Icon = r.icon;
                return (
                  <CommandItem key={r.path} value={`${t(r.titleKey)} ${r.path}`} onSelect={() => go(r.path)}>
                    <Icon className="mr-2 h-4 w-4 text-muted-foreground" />
                    {t(r.titleKey)}
                  </CommandItem>
                );
              })}
            </CommandGroup>
            {canRegions && (
              <CommandGroup heading={t('shell.commandRegions')}>
                {REGIONS.map((r) => (
                  <CommandItem key={r.id} value={`${r.nameUz} ${r.nameRu} ${r.slug}`} onSelect={() => go(`/regions/view?id=${r.id}`)}>
                    <MapPin className="mr-2 h-4 w-4 text-muted-foreground" />
                    {locale === 'ru' ? r.nameRu : r.nameUz}
                  </CommandItem>
                ))}
              </CommandGroup>
            )}
          </CommandList>
        </Command>
      </DialogContent>
    </Dialog>
  );
}
