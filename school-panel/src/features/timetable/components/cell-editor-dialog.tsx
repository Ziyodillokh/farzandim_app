'use client';

import { type FormEvent, useState } from 'react';

import { FormField } from '@/components/common/form-field';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import type { BellPeriod, TimetableWeekday } from '@/data/contracts';
import { TIMETABLE_ROOM_MAX, TIMETABLE_SUBJECT_KEYS, TIMETABLE_SUBJECT_MAX, TIMETABLE_TEACHER_MAX } from '@/data/schemas/timetable';
import { useI18n } from '@/i18n';
import { type CellValue, isCellEmpty, subjectChoice, validateCell } from '../lib/grid';

/** «Boshqa…» tanlovi: fan nomi erkin matn sifatida kiritiladi. */
const OTHER = '__other__';

export type CellTarget = { weekday: TimetableWeekday; period: BellPeriod };

/**
 * Bitta katakni tahrirlash: fan (ma'lum fanlar yoki «Boshqa…» + erkin matn), xona, o'qituvchi.
 * Hammasi bo'sh qoldirilsa — katak tozalanadi. Faqat `onApply` jadval qoralamasini o'zgartiradi.
 */
export function CellEditorDialog({
  target,
  value,
  onApply,
  onClose,
}: {
  target: CellTarget;
  value: CellValue | undefined;
  onApply: (next: CellValue | null) => void;
  onClose: () => void;
}) {
  const { t } = useI18n();
  const initial = subjectChoice(value?.subject ?? '');
  const [selected, setSelected] = useState(initial.kind === 'known' ? initial.key : initial.kind === 'custom' ? OTHER : '');
  const [custom, setCustom] = useState(initial.kind === 'custom' ? initial.text : '');
  const [room, setRoom] = useState(value?.room ?? '');
  const [teacher, setTeacher] = useState(value?.teacherName ?? '');
  const [showErrors, setShowErrors] = useState(false);

  const next: CellValue = { subject: selected === OTHER ? custom.trim() : selected, room: room.trim(), teacherName: teacher.trim() };
  const error = validateCell(next);
  const subjectError = showErrors && error && (error === 'subjectRequired' || error === 'subjectTooLong') ? t(`timetable.errors.${error}`) : undefined;
  const roomError = showErrors && error === 'roomTooLong' ? t('timetable.errors.roomTooLong') : undefined;
  const teacherError = showErrors && error === 'teacherTooLong' ? t('timetable.errors.teacherTooLong') : undefined;

  const submit = (event: FormEvent) => {
    event.preventDefault();
    if (error) {
      setShowErrors(true);
      return;
    }
    onApply(isCellEmpty(next) ? null : next);
  };

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{t('timetable.editor.title', { weekday: t(`enums.weekday.${target.weekday}`), no: target.period.no })}</DialogTitle>
          <DialogDescription>{t('timetable.editor.description', { start: target.period.start, end: target.period.end })}</DialogDescription>
        </DialogHeader>
        <form onSubmit={submit} className="grid gap-4" noValidate>
          <FormField label={t('timetable.editor.subject')} error={selected === OTHER ? undefined : subjectError ? { message: subjectError } : undefined}>
            <Select value={selected} onValueChange={setSelected}>
              <SelectTrigger aria-label={t('timetable.editor.subject')} aria-invalid={Boolean(subjectError) || undefined}>
                <SelectValue placeholder={t('timetable.editor.subjectPlaceholder')} />
              </SelectTrigger>
              <SelectContent>
                {TIMETABLE_SUBJECT_KEYS.map((key) => (
                  <SelectItem key={key} value={key}>
                    {t(`timetable.subjects.${key}`)}
                  </SelectItem>
                ))}
                <SelectItem value={OTHER}>{t('timetable.editor.other')}</SelectItem>
              </SelectContent>
            </Select>
          </FormField>
          {selected === OTHER && (
            <FormField label={t('timetable.editor.customSubject')} htmlFor="tt-custom" error={subjectError ? { message: subjectError } : undefined}>
              <Input
                id="tt-custom"
                value={custom}
                maxLength={TIMETABLE_SUBJECT_MAX}
                placeholder={t('timetable.editor.customPlaceholder')}
                aria-invalid={Boolean(subjectError) || undefined}
                onChange={(e) => setCustom(e.target.value)}
                autoFocus
              />
            </FormField>
          )}
          <div className="grid gap-4 sm:grid-cols-2">
            <FormField label={t('timetable.editor.room')} htmlFor="tt-room" error={roomError ? { message: roomError } : undefined} optional>
              <Input id="tt-room" value={room} maxLength={TIMETABLE_ROOM_MAX} placeholder={t('timetable.editor.roomPlaceholder')} onChange={(e) => setRoom(e.target.value)} />
            </FormField>
            <FormField label={t('timetable.editor.teacher')} htmlFor="tt-teacher" error={teacherError ? { message: teacherError } : undefined} optional>
              <Input
                id="tt-teacher"
                value={teacher}
                maxLength={TIMETABLE_TEACHER_MAX}
                placeholder={t('timetable.editor.teacherPlaceholder')}
                onChange={(e) => setTeacher(e.target.value)}
              />
            </FormField>
          </div>
          <DialogFooter className="mt-2 gap-2 sm:justify-between">
            <Button type="button" variant="ghost" className="text-destructive hover:text-destructive" disabled={!value} onClick={() => onApply(null)}>
              {t('timetable.editor.clear')}
            </Button>
            <div className="flex flex-col-reverse gap-2 sm:flex-row">
              <Button type="button" variant="outline" onClick={onClose}>
                {t('common.cancel')}
              </Button>
              <Button type="submit">{t('timetable.editor.apply')}</Button>
            </div>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
