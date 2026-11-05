'use client';

import { GraduationCap } from 'lucide-react';
import { useId } from 'react';

import { Checkbox } from '@/components/ui/checkbox';
import { Label } from '@/components/ui/label';
import type { AudienceKind } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { INNER_TILE } from '../styles';

/** `includeStudents` faqat butun maktab va sinflar auditoriyasida mavjud (backend shartnomasi). */
export function supportsIncludeStudents(kind: AudienceKind): boolean {
  return kind === 'SCHOOL' || kind === 'CLASSES';
}

/**
 * «O'quvchilarga ham ko'rsatish» katagi — e'lon Parvoz Growth ilovasida ham chiqadi.
 * Ota-onalar auditoriyasi (GUARDIANS) tanlansa umuman ko'rsatilmaydi.
 */
export function IncludeStudentsField({ kind, checked, onChange }: { kind: AudienceKind; checked: boolean; onChange: (next: boolean) => void }) {
  const { t } = useI18n();
  const id = useId();
  if (!supportsIncludeStudents(kind)) return null;
  return (
    <div className={cn(INNER_TILE, 'flex items-start gap-3 p-3')}>
      <Checkbox id={id} checked={checked} onCheckedChange={(on) => onChange(on === true)} aria-describedby={`${id}-hint`} className="mt-0.5" />
      <div className="min-w-0">
        <Label htmlFor={id} className="flex cursor-pointer items-center gap-1.5 text-sm font-semibold">
          <GraduationCap className="h-4 w-4 text-primary" aria-hidden />
          {t('messages.audience.includeStudents')}
        </Label>
        <p id={`${id}-hint`} className="mt-1 text-2xs leading-snug text-muted-foreground">
          {t('messages.audience.includeStudentsHint')}
        </p>
      </div>
    </div>
  );
}
