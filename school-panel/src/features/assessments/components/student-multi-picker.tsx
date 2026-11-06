'use client';

import { Check, Search, X } from 'lucide-react';
import { useRef, useState } from 'react';

import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Skeleton } from '@/components/ui/skeleton';
import { TILE } from '@/features/dashboard/lib/tile';
import { useI18n } from '@/i18n';
import { useDebounced } from '@/lib/use-debounced';
import { cn, initials } from '@/lib/utils';
import { STUDENT_PICK_MIN_QUERY, useStudentPick } from '../hooks';

export type PickedStudent = { id: string; fullName: string; className: string; grade: number };

/**
 * Shaxsiy tayinlash uchun o'quvchilarni tanlash (1..max). Qidiruv — doiradagi o'quvchilar (servis cheklaydi);
 * sinfi test parallellariga mos kelmaganlar tanlanmaydi. Klaviatura: qidiruvdan keyin natijalar ketma-ket
 * tugmalar; tanlash/olib tashlashdan keyin fokus qidiruv maydoniga qaytadi; holat ekran o'qiydigan xabar bilan.
 */
export function StudentMultiPicker({
  value,
  onChange,
  grades,
  max,
}: {
  value: readonly PickedStudent[];
  onChange: (next: PickedStudent[]) => void;
  /** Test parallellari; null — test hali tanlanmagan. */
  grades: readonly number[] | null;
  max: number;
}) {
  const { t } = useI18n();
  const [query, setQuery] = useState('');
  const [announcement, setAnnouncement] = useState('');
  const inputRef = useRef<HTMLInputElement>(null);
  const debounced = useDebounced(query);
  const search = useStudentPick(debounced);
  const full = value.length >= max;
  const ready = grades !== null;
  const items = search.data?.items;
  const searching = debounced.trim().length >= STUDENT_PICK_MIN_QUERY;

  const add = (student: PickedStudent) => {
    if (full || value.some((v) => v.id === student.id)) return;
    onChange([...value, student]);
    setAnnouncement(t('assessments.assign.studentAdded', { name: student.fullName }));
    setQuery('');
    inputRef.current?.focus();
  };
  const remove = (student: PickedStudent) => {
    onChange(value.filter((v) => v.id !== student.id));
    setAnnouncement(t('assessments.assign.studentRemoved', { name: student.fullName }));
    inputRef.current?.focus();
  };

  return (
    <div className="space-y-3">
      <Input
        ref={inputRef}
        icon={<Search />}
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder={t('assessments.assign.studentSearch')}
        aria-label={t('assessments.assign.studentSearch')}
        aria-describedby="student-picker-hint"
        disabled={!ready || full}
        autoComplete="off"
        data-testid="student-search"
      />
      <p id="student-picker-hint" className="text-xs text-muted-foreground">
        {!ready ? t('assessments.assign.studentPickTestFirst') : full ? t('assessments.assign.studentsMax', { max }) : t('assessments.assign.studentHint')}
      </p>

      {ready && searching && !full && (
        <ul aria-label={t('assessments.assign.studentsResults')} className="max-h-48 divide-y divide-border/60 overflow-y-auto rounded-xl bg-white/50 ring-1 ring-inset ring-border/60 dark:bg-white/[0.03]">
          {search.isLoading && !items ? (
            Array.from({ length: 3 }, (_, i) => (
              <li key={i} className="flex items-center gap-3 px-3 py-2">
                <Skeleton className="h-8 w-8 rounded-full" />
                <Skeleton className="h-4 w-40" />
              </li>
            ))
          ) : items?.length === 0 ? (
            <li className="px-3 py-4 text-center text-sm text-muted-foreground">{t('common.noResults')}</li>
          ) : (
            items?.map((s) => {
              const picked = value.some((v) => v.id === s.id);
              const eligible = grades.includes(s.grade);
              return (
                <li key={s.id}>
                  <button
                    type="button"
                    disabled={picked || !eligible}
                    onClick={() => add({ id: s.id, fullName: s.fullName, className: s.className, grade: s.grade })}
                    className="flex w-full items-center gap-3 px-3 py-2 text-left transition-colors hover:bg-primary/[0.05] focus-visible:bg-primary/[0.08] focus-visible:outline-none disabled:cursor-not-allowed disabled:opacity-60 disabled:hover:bg-transparent"
                  >
                    <Avatar className="h-8 w-8">
                      <AvatarFallback className="bg-gradient-to-br from-brand-400 to-brand-800 text-2xs font-semibold text-white">{initials(s.fullName)}</AvatarFallback>
                    </Avatar>
                    <span className="min-w-0 flex-1">
                      <span className="block truncate text-sm font-medium">{s.fullName}</span>
                      <span className="block text-xs text-muted-foreground">{s.studentCode}</span>
                    </span>
                    {picked ? <Check className="h-4 w-4 text-primary" aria-hidden /> : null}
                    {!eligible && (
                      <Badge variant="warning" size="sm">
                        {t('assessments.assign.studentNotEligible')}
                      </Badge>
                    )}
                    <Badge variant="outline">{s.className}</Badge>
                  </button>
                </li>
              );
            })
          )}
        </ul>
      )}

      {value.length > 0 && (
        <div className="space-y-1.5">
          <p role="status" className="text-xs font-medium tabular-nums text-muted-foreground">
            {t('assessments.assign.studentsSelected', { count: value.length, max })}
          </p>
          <ul aria-label={t('assessments.assign.studentsLabel')} className="flex flex-wrap gap-1.5" data-testid="picked-students">
            {value.map((s) => (
              <li key={s.id} className={cn(TILE, 'flex items-center gap-2 bg-primary/[0.07] py-1 pl-3 pr-1 text-sm ring-primary/30')}>
                <span className="font-medium">{s.fullName}</span>
                <Badge variant="outline" size="sm">
                  {s.className}
                </Badge>
                <Button type="button" variant="ghost" size="icon-sm" onClick={() => remove(s)} aria-label={t('assessments.assign.studentRemove', { name: s.fullName })}>
                  <X />
                </Button>
              </li>
            ))}
          </ul>
        </div>
      )}
      <span className="sr-only" role="status" aria-live="polite">
        {announcement}
      </span>
    </div>
  );
}
