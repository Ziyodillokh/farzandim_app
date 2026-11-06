'use client';

import { Clock3, Eye, HeartHandshake, UserRound } from 'lucide-react';
import type { ReactNode } from 'react';

import { SectionCard } from '@/components/common/section-card';
import type { CareStaffOption } from '@/data/contracts';
import { ICON_CHIP, TILE } from '@/features/dashboard/lib/tile';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { childFacingName, formatWorkHours, NO_STAFF, type SettingsDraft } from '../lib/settings';

function Line({ icon, label, children }: { icon: ReactNode; label: string; children: ReactNode }) {
  return (
    <li className={cn(TILE, 'flex items-center gap-3 px-3.5 py-3')}>
      <span className={cn(ICON_CHIP, 'h-8 w-8 rounded-lg bg-sky-500/10 text-sky-600 ring-sky-500/20 dark:text-sky-300 [&_svg]:size-4')}>{icon}</span>
      <div className="min-w-0">
        <p className="text-xs text-muted-foreground">{label}</p>
        <p className="truncate text-sm font-medium">{children}</p>
      </div>
    </li>
  );
}

const staffId = (value: string): string | null => (value === NO_STAFF ? null : value);

/** Bola ilovasida ko'rinadigan ma'lumot (forma o'zgarishi bilan birga yangilanadi). */
export function SettingsPreview({ draft, options }: { draft: SettingsDraft; options: readonly CareStaffOption[] }) {
  const { t } = useI18n();
  const psychologist = childFacingName(draft.psychologistDisplayName, staffId(draft.psychologistStaffId), options);
  const deputy = childFacingName(draft.deputyDisplayName, staffId(draft.deputyStaffId), options);
  const notSet = t('care.settings.previewNotSet');
  return (
    <SectionCard title={t('care.settings.previewTitle')} description={t('care.settings.previewHint')} icon={<Eye />}>
      <ul className="space-y-2" data-testid="care-settings-preview">
        <Line icon={<HeartHandshake />} label={t('care.settings.previewPsychologist')}>
          {psychologist ?? notSet}
        </Line>
        <Line icon={<UserRound />} label={t('care.settings.previewDeputy')}>
          {deputy ?? notSet}
        </Line>
        <Line icon={<Clock3 />} label={t('care.settings.previewHours')}>
          {draft.workDays.length > 0 ? formatWorkHours(t, draft) : notSet}
        </Line>
      </ul>
    </SectionCard>
  );
}
