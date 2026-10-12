'use client';

import { Search, X } from 'lucide-react';
import { useState } from 'react';

import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Skeleton } from '@/components/ui/skeleton';
import type { StudentRow } from '@/data/mock/services/students';
import { useI18n } from '@/i18n';
import { useDebounced } from '@/lib/use-debounced';
import { initials } from '@/lib/utils';
import { useStudentSearch } from '../hooks';

const MIN_QUERY = 2;

function StudentLine({ student }: { student: StudentRow }) {
  return (
    <>
      <Avatar className="h-8 w-8">
        <AvatarFallback className="bg-primary/10 text-2xs font-semibold text-primary">{initials(student.fullName)}</AvatarFallback>
      </Avatar>
      <div className="min-w-0 flex-1">
        <p className="truncate text-sm font-medium">{student.fullName}</p>
        <p className="text-xs text-muted-foreground">{student.studentCode}</p>
      </div>
      <Badge variant="outline">{student.className}</Badge>
    </>
  );
}

/** O'quvchini ism yoki kod bo'yicha qidirib tanlash. */
export function StudentPicker({ value, onChange, invalid }: { value: StudentRow | null; onChange: (s: StudentRow | null) => void; invalid?: boolean }) {
  const { t } = useI18n();
  const [query, setQuery] = useState('');
  const debounced = useDebounced(query);
  const search = useStudentSearch(debounced);

  if (value) {
    return (
      <div className="flex items-center gap-3 rounded-lg border border-primary/30 bg-primary/5 px-3 py-2.5">
        <StudentLine student={value} />
        <Button type="button" variant="ghost" size="icon-sm" onClick={() => onChange(null)} aria-label={t('attendance.earlyExit.change')}>
          <X />
        </Button>
      </div>
    );
  }

  const items = search.data?.items;
  return (
    <div className="space-y-2">
      <Input
        icon={<Search />}
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder={t('attendance.earlyExit.fields.studentSearch')}
        aria-invalid={invalid}
        className={invalid ? 'border-destructive' : undefined}
        autoFocus
      />
      {debounced.trim().length < MIN_QUERY ? (
        <p className="text-xs text-muted-foreground">{t('attendance.earlyExit.fields.studentHint')}</p>
      ) : (
        <div className="max-h-56 divide-y overflow-y-auto rounded-lg border">
          {search.isLoading && !items
            ? Array.from({ length: 3 }).map((_, i) => (
                <div key={i} className="flex items-center gap-3 px-3 py-2">
                  <Skeleton className="h-8 w-8 rounded-full" />
                  <Skeleton className="h-4 w-40" />
                </div>
              ))
            : items?.length === 0
              ? <p className="px-3 py-4 text-center text-sm text-muted-foreground">{t('common.noResults')}</p>
              : items?.map((s) => (
                  <button key={s.id} type="button" onClick={() => onChange(s)} className="flex w-full items-center gap-3 px-3 py-2 text-left transition-colors hover:bg-accent">
                    <StudentLine student={s} />
                  </button>
                ))}
        </div>
      )}
    </div>
  );
}
