'use client';

import { TriangleAlert } from 'lucide-react';
import { useMemo, useState } from 'react';

import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { useI18n } from '@/i18n';
import { cellKey, copyDay, type Grid, overwriteCount, WEEKDAYS } from '../lib/grid';

const FIRST_DAY = 1;

/**
 * Kunni boshqa kunlarga nusxalash (odatda dushanba → qolgan kunlar). Maqsad kunlar manba kun bilan
 * to'liq almashadi; nechta mavjud dars ustiga yozilishi oldindan ko'rsatiladi.
 */
export function CopyDayDialog({
  grid,
  periodNos,
  onApply,
  onClose,
}: {
  grid: Grid;
  periodNos: readonly number[];
  onApply: (next: Grid) => void;
  onClose: () => void;
}) {
  const { t, tc } = useI18n();
  const [from, setFrom] = useState<number>(FIRST_DAY);
  const [targets, setTargets] = useState<readonly number[]>(() => WEEKDAYS.filter((d) => d !== FIRST_DAY));

  const chosen = targets.filter((d) => d !== from);
  const overwrites = useMemo(() => overwriteCount(grid, from, chosen, periodNos), [grid, from, chosen, periodNos]);
  const sourceEmpty = !periodNos.some((no) => grid[cellKey(from, no)]);

  const toggle = (day: number, on: boolean) => setTargets((current) => (on ? [...new Set([...current, day])] : current.filter((d) => d !== day)));

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{t('timetable.copy.title')}</DialogTitle>
          <DialogDescription>{t('timetable.copy.description')}</DialogDescription>
        </DialogHeader>
        <div className="grid gap-5">
          <div className="space-y-1.5">
            <Label htmlFor="tt-copy-from">{t('timetable.copy.from')}</Label>
            <Select value={String(from)} onValueChange={(v) => setFrom(Number(v))}>
              <SelectTrigger id="tt-copy-from">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {WEEKDAYS.map((d) => (
                  <SelectItem key={d} value={String(d)}>
                    {t(`enums.weekday.${d}`)}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <fieldset className="space-y-2">
            <legend className="mb-1.5 text-sm font-medium">{t('timetable.copy.to')}</legend>
            <div className="grid grid-cols-2 gap-2">
              {WEEKDAYS.filter((d) => d !== from).map((d) => (
                <label key={d} className="flex cursor-pointer items-center gap-2 rounded-xl bg-white/50 px-3 py-2 text-sm ring-1 ring-inset ring-border/60 dark:bg-white/[0.03]">
                  <Checkbox checked={targets.includes(d)} onCheckedChange={(on) => toggle(d, on === true)} />
                  {t(`enums.weekday.${d}`)}
                </label>
              ))}
            </div>
          </fieldset>

          <div className="space-y-1 text-sm" aria-live="polite">
            {chosen.length === 0 ? (
              <p className="font-medium text-destructive">{t('timetable.copy.selectTargets')}</p>
            ) : overwrites > 0 ? (
              <p className="flex items-center gap-2 font-medium text-warning">
                <TriangleAlert className="h-4 w-4 shrink-0" aria-hidden />
                {tc('timetable.copy.overwrite', overwrites)}
              </p>
            ) : (
              <p className="text-muted-foreground">{t('timetable.copy.noOverwrite')}</p>
            )}
            {sourceEmpty && <p className="text-xs text-muted-foreground">{t('timetable.copy.emptySource')}</p>}
          </div>
        </div>
        <DialogFooter>
          <Button type="button" variant="outline" onClick={onClose}>
            {t('common.cancel')}
          </Button>
          <Button type="button" disabled={chosen.length === 0} onClick={() => onApply(copyDay(grid, from, chosen, periodNos))}>
            {t('timetable.copy.apply')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
