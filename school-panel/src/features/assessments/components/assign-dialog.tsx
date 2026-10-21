'use client';

import { ShieldCheck } from 'lucide-react';
import { useEffect, useMemo, useState } from 'react';

import { FormField } from '@/components/common/form-field';
import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { addDays } from '@/data/mock/calendar';
import { clockNow } from '@/data/mock/clock';
import { assignInputSchema, type AssignInput } from '@/data/schemas/assessments';
import { isHttpMode } from '@/data/source';
import { TILE } from '@/features/dashboard/lib/tile';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { useAssign, useClassOptions, useTests } from '../hooks';
import { fieldMessage, gradesLabel, toLocalInput } from '../lib/labels';
import { GradesPicker } from './grades-picker';
import { isAssignable } from './test-card';

/** Parvoz IQ (docs/IQ-REJA.md §7) — savollar IQ bankida; faqat haqiqiy panelda tayinlanadi. */
export const PARVOZ_IQ_ID = 'parvoz-iq';
const PARVOZ_IQ_OPTION = {
  id: PARVOZ_IQ_ID,
  title: { uz: 'Parvoz IQ — mantiqiy fikrlash', ru: 'Parvoz IQ — логическое мышление' },
  grades: Array.from({ length: 11 }, (_, i) => i + 1),
};

type Mode = 'CLASSES' | 'GRADES';
type Errors = Partial<Record<'testId' | 'target' | 'opensAt' | 'closesAt' | 'consent', string>>;

function defaultWindow(): { opensAt: string; closesAt: string } {
  const now = clockNow();
  const end = new Date(`${addDays(toLocalInput(now).slice(0, 10), 7)}T18:00`);
  return { opensAt: toLocalInput(now), closesAt: toLocalInput(end) };
}

/** Testni sinflar yoki parallellarga tayinlash (ota-onalar xabardorligi majburiy). */
export function AssignDialog({
  open,
  onOpenChange,
  testId: initialTestId,
  classId,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  testId?: string;
  classId?: string;
}) {
  const { t, locale } = useI18n();
  const tests = useTests({ status: 'PUBLISHED' });
  const classes = useClassOptions();
  const assign = useAssign();
  const [testId, setTestId] = useState<string | undefined>();
  const [mode, setMode] = useState<Mode>('CLASSES');
  const [classIds, setClassIds] = useState<string[]>([]);
  const [grades, setGrades] = useState<number[]>([]);
  const [period, setPeriod] = useState(defaultWindow);
  const [consent, setConsent] = useState(false);
  const [errors, setErrors] = useState<Errors>({});

  useEffect(() => {
    if (!open) return;
    setTestId(initialTestId);
    setMode('CLASSES');
    setClassIds(classId ? [classId] : []);
    setGrades([]);
    setPeriod(defaultWindow());
    setConsent(false);
    setErrors({});
  }, [open, initialTestId, classId]);

  const assignable: Array<Pick<typeof PARVOZ_IQ_OPTION, 'id' | 'title' | 'grades'>> = [
    ...(isHttpMode ? [PARVOZ_IQ_OPTION] : []),
    ...(tests.data ?? []).filter(isAssignable),
  ];
  const test = assignable.find((x) => x.id === testId);
  const eligible = useMemo(() => (classes.data ?? []).filter((c) => test?.grades.includes(c.grade)), [classes.data, test]);
  const selected = mode === 'CLASSES' ? eligible.filter((c) => classIds.includes(c.id)) : eligible.filter((c) => grades.includes(c.grade));
  const invited = selected.reduce((s, c) => s + c.size, 0);

  const submit = () => {
    const input: AssignInput = {
      testId: testId ?? '',
      target: mode === 'CLASSES' ? { kind: 'CLASSES', classIds: classIds.filter((id) => eligible.some((c) => c.id === id)) } : { kind: 'GRADES', grades },
      opensAt: period.opensAt,
      closesAt: period.closesAt,
      consent: consent as true,
    };
    const parsed = assignInputSchema.safeParse(input);
    if (!parsed.success) {
      const next: Errors = {};
      for (const issue of parsed.error.issues) {
        const key = String(issue.path[0]) as keyof Errors;
        next[key] ??= issue.message;
      }
      setErrors(next);
      return;
    }
    setErrors({});
    assign.mutate(input, { onSuccess: () => onOpenChange(false) });
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[92vh] overflow-y-auto sm:max-w-xl">
        <DialogHeader>
          <DialogTitle>{t('assessments.assign.title')}</DialogTitle>
          <DialogDescription>{t('assessments.assign.description')}</DialogDescription>
        </DialogHeader>
        <div className="grid gap-4">
          <FormField label={t('assessments.assign.test')} error={{ message: fieldMessage(t, errors.testId) }} hint={test ? t('assessments.assign.eligible', { grades: gradesLabel(t, test.grades) }) : undefined}>
            <Select value={testId} onValueChange={setTestId}>
              <SelectTrigger aria-label={t('assessments.assign.test')} data-testid="assign-test">
                <SelectValue placeholder={t('assessments.assign.testPlaceholder')} />
              </SelectTrigger>
              <SelectContent>
                {assignable.map((x) => (
                  <SelectItem key={x.id} value={x.id}>
                    {x.title[locale]}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </FormField>

          <FormField label={t('assessments.assign.target')} error={{ message: fieldMessage(t, errors.target) }}>
            <Tabs value={mode} onValueChange={(v) => setMode(v as Mode)}>
              <TabsList className="mb-2">
                <TabsTrigger value="CLASSES">{t('assessments.assign.byClasses')}</TabsTrigger>
                <TabsTrigger value="GRADES">{t('assessments.assign.byGrades')}</TabsTrigger>
              </TabsList>
            </Tabs>
            {!test ? null : eligible.length === 0 ? (
              <p className="text-sm text-muted-foreground">{t('assessments.assign.noEligible')}</p>
            ) : mode === 'CLASSES' ? (
              <div className="flex flex-wrap gap-1.5" role="group" aria-label={t('assessments.assign.byClasses')}>
                {eligible.map((c) => {
                  const on = classIds.includes(c.id);
                  return (
                    <label key={c.id} className={cn(TILE, 'flex cursor-pointer items-center gap-2 px-2.5 py-1.5 text-sm font-medium', on && 'bg-primary/[0.07] ring-primary/40 dark:bg-primary/[0.12]')}>
                      <Checkbox checked={on} onCheckedChange={(v) => setClassIds(v === true ? [...classIds, c.id] : classIds.filter((x) => x !== c.id))} aria-label={c.name} />
                      {c.name}
                    </label>
                  );
                })}
              </div>
            ) : (
              <GradesPicker value={grades} onChange={setGrades} allowed={test.grades} />
            )}
          </FormField>

          <div className="grid gap-4 sm:grid-cols-2">
            <FormField label={t('assessments.assign.opensAt')} htmlFor="as-open" error={{ message: fieldMessage(t, errors.opensAt) }}>
              <Input id="as-open" type="datetime-local" value={period.opensAt} onChange={(e) => setPeriod({ ...period, opensAt: e.target.value })} />
            </FormField>
            <FormField label={t('assessments.assign.closesAt')} htmlFor="as-close" error={{ message: fieldMessage(t, errors.closesAt) }}>
              <Input id="as-close" type="datetime-local" value={period.closesAt} onChange={(e) => setPeriod({ ...period, closesAt: e.target.value })} />
            </FormField>
          </div>

          <label className={cn(TILE, 'flex cursor-pointer items-start gap-3 p-3', errors.consent && 'ring-destructive/50')}>
            <Checkbox className="mt-0.5" checked={consent} onCheckedChange={(v) => setConsent(v === true)} data-testid="assign-consent" />
            <span className="text-sm">
              <span className="flex items-center gap-1.5 font-medium">
                <ShieldCheck className="h-4 w-4 text-primary" />
                {t('assessments.assign.consent')}
              </span>
              <span className="mt-0.5 block text-xs text-muted-foreground">{fieldMessage(t, errors.consent) ?? t('assessments.assign.consentHint')}</span>
            </span>
          </label>
          {selected.length > 0 && <p className="text-sm font-medium tabular-nums text-primary">{t('assessments.assign.invited', { count: invited })}</p>}
        </div>
        <DialogFooter className="mt-2">
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button onClick={submit} loading={assign.isPending} data-testid="assign-submit">
            {t('assessments.assign.submit')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
