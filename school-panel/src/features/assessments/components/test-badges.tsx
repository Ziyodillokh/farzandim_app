'use client';

import { Badge } from '@/components/ui/badge';
import type { AssignmentState, PsychTestKind, PsychTestSource, PsychTestStatus, ScoreBand } from '@/data/contracts';
import { ICON_CHIP } from '@/features/dashboard/lib/tile';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { BAND_VARIANT, bandLabel, KIND_ICON, KIND_TONE, SOURCE_VARIANT, STATE_VARIANT, STATUS_VARIANT } from '../lib/labels';

export function KindIcon({ kind, className }: { kind: PsychTestKind; className?: string }) {
  const Icon = KIND_ICON[kind];
  return (
    <span className={cn(ICON_CHIP, 'h-10 w-10 [&_svg]:size-5', KIND_TONE[kind], className)} aria-hidden>
      <Icon />
    </span>
  );
}

export function SourceBadge({ source }: { source: PsychTestSource }) {
  const { t } = useI18n();
  return (
    <Badge variant={SOURCE_VARIANT[source]} size="sm">
      {t(`enums.psychSource.${source}`)}
    </Badge>
  );
}

export function StatusBadge({ status }: { status: PsychTestStatus }) {
  const { t } = useI18n();
  return (
    <Badge variant={STATUS_VARIANT[status]} size="sm">
      {t(`enums.psychStatus.${status}`)}
    </Badge>
  );
}

export function StateBadge({ state }: { state: AssignmentState }) {
  const { t } = useI18n();
  return (
    <Badge variant={STATE_VARIANT[state]}>
      {state === 'ACTIVE' && <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-current" aria-hidden />}
      {t(`enums.assignmentState.${state}`)}
    </Badge>
  );
}

/** Daraja chipi — qisqa yorliq, to'liq tavsif sarlavhada (title). */
export function BandBadge({ band, size }: { band: ScoreBand | null; size?: 'sm' | 'default' }) {
  const { t } = useI18n();
  if (!band) return <span className="text-muted-foreground">—</span>;
  return (
    <Badge variant={BAND_VARIANT[band]} size={size} title={bandLabel(t, band)} className="whitespace-nowrap">
      {bandLabel(t, band, true)}
    </Badge>
  );
}
