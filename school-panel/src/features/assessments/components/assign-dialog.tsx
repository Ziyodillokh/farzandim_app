'use client';

import { Lock, ShieldCheck } from 'lucide-react';
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
import { assignInputSchema, type AssignInput, PSYCH_LIMITS } from '@/data/schemas/assessments';
import { isHttpMode } from '@/data/source';
import { TILE } from '@/features/dashboard/lib/tile';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { useAssign, useClassOptions, useTests } from '../hooks';
import { fieldMessage, gradesLabel, toLocalInput } from '../lib/labels';
import { GradesPicker } from './grades-picker';
import { type PickedStudent, StudentMultiPicker } from './student-multi-picker';
import { isAssignable } from './test-card';

/** Parvoz IQ (docs/IQ-REJA.md §7) — savollar IQ bankida; faqat haqiqiy panelda tayinlanadi. */
export const PARVOZ_IQ_ID = 'parvoz-iq';
const PARVOZ_IQ_OPTION = {
  id: PARVOZ_IQ_ID,
  title: { uz: 'Parvoz IQ — mantiqiy fikrlash', ru: 'Parvoz IQ — логическое мышление' },
  grades: Array.from({ length: 11 }, (_, i) => i + 1),
};

type Mode = 'CLASSES' | 'GRADES' | 'STUDENTS';

/** Murojaatdan ochilganda: tayinlash FAQAT shu o'quvchiga va murojaatga bog'lanadi (maqsad o'zgartirilmaydi). */
export type AssignPrefill = { studentId: string; studentName: string; classId: string; careRequestId: string };
type Errors = Partial<Record<'testId' | 'target' | 'opensAt' | 'closesAt' | 'consent', string>>;

function defaultWindow(): { opensAt: string; closesAt: string } {
  const now = clockNow();
  const end = new Date(`${addDays(toLocalInput(now).slice(0, 10), 7)}T18:00`);
  return { opensAt: toLocalInput(now), closesAt: toLocalInput(end) };
}

/**
 * Testni sinflar, parallellar yoki alohida o'quvchilarga tayinlash (ota-onalar xabardorligi majburiy).
 * `prefill` — murojaatdan «Shaxsiy so'rov tayinlash»: maqsad qulflangan (bitta o'quvchi), `careRequestId` yuboriladi.
 */
export function AssignDialog({
  open,
  onOpenChange,
  testId: initialTestId,
  classId,
  prefill,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  testId?: string;
  classId?: string;
  prefill?: AssignPrefill;
}) {
  const { t, locale } = useI18n();
  const tests = useTests({ status: 'PUBLISHED' });
  const classes = useClassOptions();
  const assign = useAssign();
  const [testId, setTestId] = useState<string | undefined>();
  const [mode, setMode] = useState<Mode>('CLASSES');
  const [classIds, setClassIds] = useState<string[]>([]);
  const [grades, setGrades] = useState<number[]>([]);
  const [students, setStudents] = useState<PickedStudent[]>([]);
  const [period, setPeriod] = useState(defaultWindow);
  const [consent, setConsent] = useState(false);
  const [errors, setErrors] = useState<Errors>({});

  useEffect(() => {
    if (!open) return;
    setTestId(initialTestId);
    setMode('CLASSES');
    setClassIds(classId ? [classId] : []);
    setGrades([]);
    setStudents([]);
    setPeriod(defaultWindow());
    setConsent(false);
    setErrors({});
  }, [open, initialTestId, classId, prefill?.studentId, prefill?.careRequestId]);

  const assignable: Array<Pick<typeof PARVOZ_IQ_OPTION, 'id' | 'title' | 'grades'>> = [
    ...(isHttpMode ? [PARVOZ_IQ_OPTION] : []),
    ...(tests.data ?? []).filter(isAssignable),
  ];
  const test = assignable.find((x) => x.id === testId);
  const eligible = useMemo(() => (classes.data ?? []).filter((c) => test?.grades.includes(c.grade)), [classes.data, test]);
  const targetMode: Mode = prefill ? 'STUDENTS' : mode;
  const prefillClass = prefill ? classes.data?.find((c) => c.id === prefill.classId) : undefined;
  const chosen: PickedStudent[] = prefill
    ? [{ id: prefill.studentId, fullName: prefill.studentName, className: prefillClass?.name ?? '—', grade: prefillClass?.grade ?? 0 }]
    : students;
  const mismatched = test ? chosen.filter((s) => !test.grades.includes(s.grade)) : [];
  const selected = mode === 'CLASSES' ? eligible.filter((c) => classIds.includes(c.id)) : eligible.filter((c) => grades.includes(c.grade));
  const invited = targetMode === 'STUDENTS' ? chosen.length : selected.reduce((s, c) => s + c.size, 0);

  const submit = () => {
    const input: AssignInput = {
      testId: testId ?? '',
      target:
        targetMode === 'STUDENTS'
          ? { kind: 'STUDENTS', studentIds: chosen.map((s) => s.id) }
          : targetMode === 'CLASSES'
            ? { kind: 'CLASSES', classIds: classIds.filter((id) => eligible.some((c) => c.id === id)) }
            : { kind: 'GRADES', grades },
      opensAt: period.opensAt,
      closesAt: period.closesAt,
      consent: consent as true,
      ...(prefill ? { careRequestId: prefill.careRequestId } : {}),
    };
    if (test && mismatched.length > 0) {
      setErrors({ target: t('assessments.assign.studentIneligible', { grades: gradesLabel(t, test.grades) }) });
      return;
    }
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
          <DialogTitle>{prefill ? t('assessments.assign.personalTitle') : t('assessments.assign.title')}</DialogTitle>
          <DialogDescription>{prefill ? t('assessments.assign.personalDescription') : t('assessments.assign.description')}</DialogDescription>
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
            {prefill ? (
              <div className={cn(TILE, 'flex items-start gap-3 bg-primary/[0.06] p-3 ring-primary/30')} data-testid="assign-locked-student">
                <Lock className="mt-0.5 h-4 w-4 shrink-0 text-primary" aria-hidden />
                <div className="min-w-0 text-sm">
                  <p className="font-medium">
                    {prefill.studentName} <span className="font-normal text-muted-foreground">· {prefillClass?.name ?? '—'}</span>
                  </p>
                  <p className="text-xs text-muted-foreground">{t('assessments.assign.linkedRequest')}</p>
                </div>
              </div>
            ) : (
              <>
                <Tabs value={mode} onValueChange={(v) => setMode(v as Mode)}>
                  <TabsList className="mb-2 h-auto flex-wrap justify-start">
                    <TabsTrigger value="CLASSES">{t('assessments.assign.byClasses')}</TabsTrigger>
                    <TabsTrigger value="GRADES">{t('assessments.assign.byGrades')}</TabsTrigger>
                    <TabsTrigger value="STUDENTS" data-testid="assign-mode-students">
                      {t('assessments.assign.byStudents')}
                    </TabsTrigger>
                  </TabsList>
                </Tabs>
                {mode === 'STUDENTS' ? (
                  <StudentMultiPicker value={students} onChange={setStudents} grades={test?.grades ?? null} max={PSYCH_LIMITS.personalStudents} />
                ) : !test ? null : eligible.length === 0 ? (
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
              </>
            )}
            {prefill && test && mismatched.length > 0 && (
              <p role="alert" className="mt-2 text-xs font-medium text-destructive">
                {t('assessments.assign.studentIneligible', { grades: gradesLabel(t, test.grades) })}
              </p>
            )}
            {targetMode === 'STUDENTS' && (
              <p role="note" className="mt-2 flex items-start gap-1.5 text-xs text-muted-foreground">
                <ShieldCheck className="mt-0.5 h-3.5 w-3.5 shrink-0 text-primary" aria-hidden />
                {t('assessments.assign.personalNote')}
              </p>
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
          {invited > 0 && <p className="text-sm font-medium tabular-nums text-primary">{t('assessments.assign.invited', { count: invited })}</p>}
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
