'use client';

import { CircleDot, CheckCircle2, Copy, Save, Undo2 } from 'lucide-react';

import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import type { ClassRow } from '@/data/mock/services/classes';
import { useI18n } from '@/i18n';

/** Sinf tanlagich, smena va tahrir amallari (nusxalash, bekor qilish, saqlash). */
export function TimetableToolbar({
  classes,
  classId,
  onClassChange,
  shiftName,
  lessonCount,
  canManage,
  isDirty,
  isSaving,
  onCopy,
  onDiscard,
  onSave,
}: {
  classes: readonly Pick<ClassRow, 'id' | 'name'>[];
  classId: string;
  onClassChange: (id: string) => void;
  shiftName: string | null;
  lessonCount: number;
  canManage: boolean;
  isDirty: boolean;
  isSaving: boolean;
  onCopy: () => void;
  onDiscard: () => void;
  onSave: () => void;
}) {
  const { t, tc } = useI18n();
  return (
    <div className="flex flex-wrap items-end justify-between gap-4">
      <div className="flex flex-wrap items-end gap-3">
        <div className="w-40 space-y-1.5">
          <Label htmlFor="tt-class">{t('timetable.classLabel')}</Label>
          <Select value={classId} onValueChange={onClassChange}>
            <SelectTrigger id="tt-class">
              <SelectValue placeholder={t('timetable.classPlaceholder')} />
            </SelectTrigger>
            <SelectContent>
              {classes.map((c) => (
                <SelectItem key={c.id} value={c.id}>
                  {c.name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <div className="flex flex-wrap items-center gap-2 pb-2">
          {shiftName && <Badge variant="outline">{t('timetable.shift', { name: shiftName })}</Badge>}
          <Badge variant="secondary" className="tabular-nums">
            {tc('timetable.lessonsCount', lessonCount)}
          </Badge>
        </div>
      </div>

      {canManage && (
        <div className="flex flex-wrap items-center gap-2">
          <p className="flex items-center gap-1.5 text-xs text-muted-foreground" role="status">
            {isDirty ? <CircleDot className="h-3.5 w-3.5 text-warning" aria-hidden /> : <CheckCircle2 className="h-3.5 w-3.5 text-success" aria-hidden />}
            {isDirty ? t('timetable.unsaved') : t('timetable.allSaved')}
          </p>
          <Button type="button" variant="outline" size="sm" onClick={onCopy}>
            <Copy />
            {t('timetable.copyDay')}
          </Button>
          <Button type="button" variant="ghost" size="sm" onClick={onDiscard} disabled={!isDirty || isSaving}>
            <Undo2 />
            {t('timetable.discard')}
          </Button>
          <Button type="button" size="sm" onClick={onSave} disabled={!isDirty} loading={isSaving}>
            <Save />
            {t('timetable.save')}
          </Button>
        </div>
      )}
    </div>
  );
}
