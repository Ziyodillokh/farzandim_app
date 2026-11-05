'use client';

import { GraduationCap, School, Users, UsersRound } from 'lucide-react';

import { Badge } from '@/components/ui/badge';
import type { AudienceKind } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

const ICONS = { SCHOOL: School, CLASSES: Users, GUARDIANS: UsersRound } as const;

/** Auditoriya qisqa ko'rinishi: "Butun maktab" yoki "5-A, 5-B, +3". */
export function AudienceChips({
  kind,
  names,
  max = 4,
  includeStudents = false,
  className,
}: {
  kind: AudienceKind;
  names: string[];
  max?: number;
  /** E'lon o'quvchilarga ham (Parvoz Growth ilovasida) ko'rinadi. */
  includeStudents?: boolean;
  className?: string;
}) {
  const { t } = useI18n();
  const Icon = ICONS[kind];
  const shown = names.slice(0, max);
  const rest = names.length - shown.length;
  return (
    <div className={cn('flex flex-wrap items-center gap-1.5', className)}>
      <Badge variant="default" className="gap-1.5">
        <Icon className="h-3 w-3" />
        {t(`enums.audienceKind.${kind}`)}
      </Badge>
      {shown.map((name) => (
        <Badge key={name} variant="outline" className="font-medium">
          {name}
        </Badge>
      ))}
      {rest > 0 && (
        <Badge variant="secondary" className="tabular-nums">
          {t('messages.card.more', { count: rest })}
        </Badge>
      )}
      {includeStudents && kind !== 'GUARDIANS' && (
        <Badge variant="info" className="gap-1">
          <GraduationCap className="h-3 w-3" aria-hidden />
          {t('messages.audience.studentsAlsoSee')}
        </Badge>
      )}
    </div>
  );
}
