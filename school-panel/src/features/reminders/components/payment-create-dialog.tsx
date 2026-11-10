'use client';

import { Check, School, UserRound } from 'lucide-react';
import { useEffect, useMemo, useState } from 'react';

import { FormField } from '@/components/common/form-field';
import { SearchInput } from '@/components/common/toolbar';
import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Skeleton } from '@/components/ui/skeleton';
import { Textarea } from '@/components/ui/textarea';
import { Segmented } from '@/features/messages/components/compose-sections';
import { INNER_TILE, SELECTED_SOFT } from '@/features/messages/styles';
import { type GuardianRow, useGuardians } from '@/features/parents/hooks';
import { useClassOptions } from '@/features/students/hooks';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { useBulkCreatePayments, useCreatePayment } from '../hooks';

type Mode = 'class' | 'family';
const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;
const GUARDIAN_LIMIT = 8;

/**
 * Yangi to'lov eslatmasi: butun sinf (eslatmasi yo'q har o'quvchi uchun bitta oila — ilovaga ulangan
 * vasiy afzal) yoki bitta oila (vasiy va farzandlari). Asos (izoh) majburiy — audit uchun.
 */
export function PaymentCreateDialog({
  open,
  onOpenChange,
  defaultClassId,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  defaultClassId?: string;
}) {
  const { t } = useI18n();
  const classes = useClassOptions();
  const bulk = useBulkCreatePayments();
  const single = useCreatePayment();
  const [mode, setMode] = useState<Mode>('class');
  const [classId, setClassId] = useState('');
  const [search, setSearch] = useState('');
  const [guardian, setGuardian] = useState<GuardianRow | null>(null);
  const [studentIds, setStudentIds] = useState<string[]>([]);
  const [nextDate, setNextDate] = useState('');
  const [note, setNote] = useState('');
  const [touched, setTouched] = useState(false);
  const guardians = useGuardians({ page: 1, limit: GUARDIAN_LIMIT, search: search.trim() || undefined, classId: classId || undefined, sortBy: 'name', sortDir: 'asc' });

  useEffect(() => {
    if (!open) return;
    setMode('class');
    setClassId(defaultClassId ?? '');
    setSearch('');
    setGuardian(null);
    setStudentIds([]);
    setNextDate('');
    setNote('');
    setTouched(false);
  }, [open, defaultClassId]);

  const pickGuardian = (g: GuardianRow) => {
    setGuardian(g);
    setStudentIds(g.children.map((c) => c.id));
  };
  const toggleStudent = (id: string) => setStudentIds((ids) => (ids.includes(id) ? ids.filter((x) => x !== id) : [...ids, id]));

  const errors = useMemo(
    () => ({
      classId: mode === 'class' && !classId,
      guardian: mode === 'family' && (!guardian || studentIds.length === 0),
      date: !ISO_DATE.test(nextDate),
      note: note.trim().length === 0,
    }),
    [mode, classId, guardian, studentIds, nextDate, note],
  );

  const submit = async () => {
    setTouched(true);
    if (Object.values(errors).some(Boolean)) return;
    try {
      if (mode === 'class') await bulk.mutateAsync({ classId, nextDate, note });
      else if (guardian) await single.mutateAsync({ guardianId: guardian.id, studentIds, nextDate, note });
      onOpenChange(false);
    } catch {
      // Xato toast orqali ko'rsatildi.
    }
  };

  const fieldError = (failed: boolean, message: string) => (touched && failed ? { message } : undefined);

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[92vh] overflow-y-auto sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>{t('reminders.payments.create.title')}</DialogTitle>
          <DialogDescription>{t('reminders.payments.create.description')}</DialogDescription>
        </DialogHeader>

        <div className="space-y-4">
          <Segmented<Mode>
            value={mode}
            onChange={setMode}
            options={[
              { value: 'class', label: t('reminders.payments.create.modeClass'), icon: <School /> },
              { value: 'family', label: t('reminders.payments.create.modeFamily'), icon: <UserRound /> },
            ]}
          />

          <FormField
            label={mode === 'class' ? t('reminders.payments.create.class') : t('reminders.payments.create.classFilter')}
            error={fieldError(errors.classId, 'errors.form.required')}
          >
            {/* Bo'sh qiymat — placeholder ("Sinfni tanlang"); bitta oila rejimida "Barchasi". */}
            <Select value={classId || (mode === 'family' ? 'all' : '')} onValueChange={(v) => setClassId(v === 'all' ? '' : v)}>
              <SelectTrigger className="sm:w-56">
                <SelectValue placeholder={t('reminders.payments.create.classPlaceholder')} />
              </SelectTrigger>
              <SelectContent>
                {mode === 'family' && <SelectItem value="all">{t('common.all')}</SelectItem>}
                {(classes.data ?? []).map((c) => (
                  <SelectItem key={c.id} value={c.id}>
                    {c.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </FormField>

          {mode === 'class' ? (
            <p className={cn(INNER_TILE, 'px-4 py-3 text-sm text-muted-foreground')}>{t('reminders.payments.create.classHint')}</p>
          ) : (
            <FormField label={t('reminders.payments.create.guardian')} error={fieldError(errors.guardian, 'errors.form.selectAtLeastOne')}>
              <div className="space-y-2">
                <SearchInput value={search} onChange={setSearch} placeholder={t('reminders.payments.create.guardianSearch')} />
                <div className="max-h-56 space-y-1.5 overflow-y-auto">
                  {guardians.isLoading
                    ? Array.from({ length: 3 }, (_, i) => <Skeleton key={i} className="h-12 rounded-xl" />)
                    : (guardians.data?.items ?? []).map((g) => {
                        const chosen = guardian?.id === g.id;
                        return (
                          <button
                            key={g.id}
                            type="button"
                            onClick={() => pickGuardian(g)}
                            className={cn(INNER_TILE, 'flex w-full items-center justify-between gap-3 px-3 py-2 text-left text-sm transition', chosen && SELECTED_SOFT)}
                          >
                            <span className="min-w-0">
                              <span className="block truncate font-medium">{g.fullName}</span>
                              <span className="block truncate text-xs text-muted-foreground">
                                {g.children.map((c) => `${c.name} · ${c.className}`).join(', ') || g.phone}
                              </span>
                            </span>
                            {chosen && <Check className="h-4 w-4 shrink-0 text-primary" />}
                          </button>
                        );
                      })}
                  {!guardians.isLoading && (guardians.data?.items.length ?? 0) === 0 && (
                    <p className="px-1 py-2 text-sm text-muted-foreground">{t('reminders.payments.create.noGuardians')}</p>
                  )}
                </div>
                {guardian && guardian.children.length > 1 && (
                  <div className={cn(INNER_TILE, 'space-y-2 p-3')}>
                    <p className="text-xs font-medium text-muted-foreground">{t('reminders.payments.create.children')}</p>
                    {guardian.children.map((c) => (
                      <label key={c.id} className="flex cursor-pointer items-center gap-2 text-sm">
                        <Checkbox checked={studentIds.includes(c.id)} onCheckedChange={() => toggleStudent(c.id)} />
                        {c.name} <span className="text-muted-foreground">· {c.className}</span>
                      </label>
                    ))}
                  </div>
                )}
              </div>
            </FormField>
          )}

          <FormField label={t('reminders.payments.create.nextDate')} htmlFor="pay-create-date" error={fieldError(errors.date, 'errors.form.invalidDate')}>
            <Input id="pay-create-date" type="date" value={nextDate} onChange={(e) => setNextDate(e.target.value)} className="sm:w-56" />
          </FormField>

          <FormField label={t('reminders.payments.shift.note')} htmlFor="pay-create-note" error={fieldError(errors.note, 'errors.form.required')}>
            <Textarea id="pay-create-note" rows={2} value={note} onChange={(e) => setNote(e.target.value)} placeholder={t('reminders.payments.create.notePlaceholder')} />
          </FormField>
        </div>

        <DialogFooter className="gap-2">
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button onClick={() => void submit()} loading={bulk.isPending || single.isPending}>
            {t('reminders.payments.create.submit')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
