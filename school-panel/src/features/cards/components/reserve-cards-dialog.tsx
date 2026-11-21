'use client';

import { useEffect, useState } from 'react';

import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { useClasses } from '@/features/classes/hooks';
import { useI18n } from '@/i18n';
import { useReserveCards } from '../batch-hooks';

const NO_FILTER = {};

/** Sinflarni tanlab, kartasiz o'quvchilarga 10 xonali raqam ajratish (bosmaxona partiyasi). */
export function ReserveCardsDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (open: boolean) => void }) {
  const { t } = useI18n();
  const classes = useClasses(NO_FILTER);
  const reserve = useReserveCards();
  const [selected, setSelected] = useState<ReadonlySet<string>>(new Set());

  useEffect(() => {
    if (!open) setSelected(new Set());
  }, [open]);

  const rows = classes.data ?? [];
  const allSelected = rows.length > 0 && selected.size === rows.length;
  const toggle = (id: string) =>
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-xl">
        <DialogHeader>
          <DialogTitle>{t('cards.batch.reserveTitle')}</DialogTitle>
          <DialogDescription>{t('cards.batch.reserveText')}</DialogDescription>
        </DialogHeader>

        <label className="flex w-fit cursor-pointer items-center gap-2.5 text-sm font-medium">
          <Checkbox checked={allSelected} onCheckedChange={(v) => setSelected(v === true ? new Set(rows.map((c) => c.id)) : new Set())} />
          {t('cards.batch.selectAll')}
        </label>
        <div className="grid max-h-80 grid-cols-2 gap-2 overflow-y-auto pr-1 sm:grid-cols-3">
          {rows.map((c) => (
            <label key={c.id} className="flex min-w-0 cursor-pointer items-center gap-2 rounded-xl border px-3 py-2 text-sm transition-colors hover:bg-muted/60">
              <Checkbox checked={selected.has(c.id)} onCheckedChange={() => toggle(c.id)} />
              <span className="font-medium">{c.name}</span>
              <span className="ml-auto whitespace-nowrap text-2xs text-muted-foreground">{t('cards.batch.students', { count: c.size })}</span>
            </label>
          ))}
        </div>

        <DialogFooter>
          <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button
            type="button"
            disabled={selected.size === 0}
            loading={reserve.isPending}
            onClick={() => reserve.mutate({ classIds: [...selected] }, { onSuccess: () => onOpenChange(false) })}
          >
            {t('cards.batch.reserve')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
