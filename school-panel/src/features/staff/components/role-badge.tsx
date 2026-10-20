'use client';

import { Badge } from '@/components/ui/badge';
import type { RoleKey } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

/** Rol nuqtasi — faqat ko'k / osmon / feruza tuslari (status ranglari emas). */
export const ROLE_DOT: Record<RoleKey, string> = {
  DIRECTOR: 'bg-brand-600',
  ADMIN: 'bg-sky-500',
  HOMEROOM: 'bg-cyan-500',
  PSYCHOLOGIST: 'bg-blue-400',
  DUTY: 'bg-slate-400',
  TEACHER: 'bg-sky-300',
};

export function RoleBadge({ role, className }: { role: RoleKey; className?: string }) {
  const { t } = useI18n();
  return (
    <Badge variant="outline" className={cn('gap-1.5 whitespace-nowrap font-medium', className)}>
      <span className={cn('h-1.5 w-1.5 rounded-full', ROLE_DOT[role])} aria-hidden />
      {t(`enums.role.${role}`)}
    </Badge>
  );
}
