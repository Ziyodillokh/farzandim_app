'use client';

import { BookOpen, BriefcaseBusiness, DoorOpen, GraduationCap, HeartHandshake, Landmark } from 'lucide-react';
import type { ComponentType } from 'react';

import type { RoleDefinition } from '@/auth/permissions';
import { StaffAvatar } from '@/components/common/staff-avatar';
import { Card } from '@/components/ui/card';
import type { RoleKey } from '@/data/contracts';
import type { StaffRow } from '@/data/mock/services/staff';
import { SOFT_BORDER } from '@/features/classes/styles';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { ROLE_DOT } from './role-badge';

const MAX_FACES = 4;

const ROLE_ICON: Record<RoleKey, ComponentType<{ className?: string }>> = {
  DIRECTOR: Landmark,
  ADMIN: BriefcaseBusiness,
  HOMEROOM: GraduationCap,
  PSYCHOLOGIST: HeartHandshake,
  DUTY: DoorOpen,
  TEACHER: BookOpen,
};

/** Rol egalari — ustma-ust portretlar. */
function Faces({ people }: { people: StaffRow[] }) {
  if (people.length === 0) return null;
  const extra = people.length - MAX_FACES;
  return (
    <div className="flex items-center" title={people.map((p) => p.fullName).join(', ')}>
      {people.slice(0, MAX_FACES).map((p) => (
        <StaffAvatar
          key={p.id}
          name={p.fullName}
          photo={p.photo ?? null}
          portrait={p.portrait ?? null}
          size="sm"
          className="-ml-2 ring-2 ring-background first:ml-0"
        />
      ))}
      {extra > 0 && (
        <span className="-ml-2 flex h-8 min-w-8 items-center justify-center rounded-full bg-muted px-1.5 text-[0.65rem] font-semibold text-muted-foreground ring-2 ring-background">
          +{extra}
        </span>
      )}
    </div>
  );
}

export function RoleCard({ role, people }: { role: RoleDefinition; people: StaffRow[] | undefined }) {
  const { t } = useI18n();
  const Icon = ROLE_ICON[role.key];
  return (
    <Card className="card-glow flex flex-col p-5 animate-slide-up">
      <div className="flex items-start gap-3">
        <span className="relative flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary ring-1 ring-inset ring-primary/15">
          <Icon className="h-[18px] w-[18px]" />
          <span className={cn('absolute -right-0.5 -top-0.5 h-2.5 w-2.5 rounded-full ring-2 ring-background', ROLE_DOT[role.key])} aria-hidden />
        </span>
        <div className="min-w-0 flex-1">
          <p className="font-semibold leading-tight">{t(`enums.role.${role.key}`)}</p>
          <p className="mt-1 text-2xs font-semibold uppercase tracking-[0.08em] text-muted-foreground">{t(`staff.roles.scope.${role.scope}`)}</p>
        </div>
      </div>
      <p className="mt-3 flex-1 text-sm leading-relaxed text-muted-foreground">{t(`staff.roles.desc.${role.key}`)}</p>
      <div className={cn('mt-4 flex min-h-[44px] items-center justify-between gap-3 border-t pt-3 text-xs', SOFT_BORDER)}>
        <div className="min-w-0">
          <p className="font-semibold">{t('staff.roles.permCount', { count: role.permissions.length })}</p>
          {people && <p className="text-muted-foreground">{t('staff.roles.staffCount', { count: people.length })}</p>}
        </div>
        {people && <Faces people={people} />}
      </div>
    </Card>
  );
}
