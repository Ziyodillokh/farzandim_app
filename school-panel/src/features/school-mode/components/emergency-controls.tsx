'use client';

import { Power, Siren } from 'lucide-react';
import { useState } from 'react';

import { Can } from '@/auth/can';
import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { Button } from '@/components/ui/button';
import { Label } from '@/components/ui/label';
import type { SchoolModeOverview } from '@/data/mock/services/school-mode';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { useActivateEmergency, useDeactivateEmergency } from '../hooks';
import { SEG_OFF, SEG_ON, SEG_TRACK, TILE } from '../lib';

type Scope = 'SCHOOL' | 'CLASS';

function ScopePicker({
  scope,
  onScope,
  classes,
  selected,
  onToggle,
}: {
  scope: Scope;
  onScope: (scope: Scope) => void;
  classes: SchoolModeOverview['classes'];
  selected: string[];
  onToggle: (id: string) => void;
}) {
  const { t } = useI18n();
  return (
    <div className="space-y-3">
      <Label>{t('schoolMode.emergency.scope')}</Label>
      <div className={cn('grid grid-cols-2 gap-1', SEG_TRACK)} role="radiogroup">
        {(['SCHOOL', 'CLASS'] as const).map((value) => (
          <button
            key={value}
            type="button"
            role="radio"
            aria-checked={scope === value}
            onClick={() => onScope(value)}
            className={cn('h-9 rounded-lg px-3 text-sm font-medium transition-all', scope === value ? SEG_ON : SEG_OFF)}
          >
            {value === 'SCHOOL' ? t('schoolMode.emergency.scopeSchool') : t('schoolMode.emergency.scopeClass')}
          </button>
        ))}
      </div>
      {scope === 'CLASS' && (
        <div className={cn('flex max-h-40 flex-wrap gap-1.5 overflow-y-auto p-2', TILE)}>
          {classes.map((c) => {
            const on = selected.includes(c.classId);
            return (
              <button
                key={c.classId}
                type="button"
                aria-pressed={on}
                onClick={() => onToggle(c.classId)}
                className={cn(
                  'rounded-lg px-2.5 py-1 text-xs font-semibold tabular-nums ring-1 ring-inset transition-colors',
                  on ? 'bg-destructive/10 text-destructive ring-destructive/40' : 'bg-card/70 ring-border/60 hover:ring-destructive/40',
                )}
              >
                {c.className}
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
}

/** "Favqulodda o'chirish" (sabab majburiy) va "Qayta yoqish" — faqat director/admin. */
export function EmergencyControls({ overview }: { overview: SchoolModeOverview | undefined }) {
  const { t } = useI18n();
  const [openOn, setOpenOn] = useState(false);
  const [openOff, setOpenOff] = useState(false);
  const [scope, setScope] = useState<Scope>('SCHOOL');
  const [selected, setSelected] = useState<string[]>([]);
  const activate = useActivateEmergency();
  const deactivate = useDeactivateEmergency();
  if (!overview) return null;
  const { emergency } = overview;
  const schoolWide = emergency.active && emergency.scope === 'SCHOOL';

  const toggle = (id: string) => setSelected((prev) => (prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id]));
  const confirmOn = (reason: string) =>
    activate.mutate(
      { scope, classIds: scope === 'CLASS' ? selected : [], reason },
      {
        onSuccess: () => {
          setOpenOn(false);
          setSelected([]);
        },
      },
    );

  return (
    <Can perm="schoolMode.emergency">
      {emergency.active && (
        <Button size="lg" variant="outline" onClick={() => setOpenOff(true)}>
          <Power />
          {t('schoolMode.emergency.restore')}
        </Button>
      )}
      {!schoolWide && (
        <Button size="lg" variant="destructive" onClick={() => setOpenOn(true)}>
          <Siren />
          {t('schoolMode.emergency.button')}
        </Button>
      )}
      <ConfirmDialog
        open={openOn}
        onOpenChange={setOpenOn}
        title={t('schoolMode.emergency.title')}
        description={t('schoolMode.emergency.description')}
        confirmLabel={t('schoolMode.emergency.confirm')}
        reasonLabel={t('schoolMode.emergency.reason')}
        destructive
        requireReason
        loading={activate.isPending}
        onConfirm={confirmOn}
      >
        <ScopePicker scope={scope} onScope={setScope} classes={overview.classes} selected={selected} onToggle={toggle} />
      </ConfirmDialog>
      <ConfirmDialog
        open={openOff}
        onOpenChange={setOpenOff}
        title={t('schoolMode.emergency.restoreTitle')}
        description={t('schoolMode.emergency.restoreDescription')}
        confirmLabel={t('schoolMode.emergency.restore')}
        loading={deactivate.isPending}
        onConfirm={() => deactivate.mutate(undefined, { onSuccess: () => setOpenOff(false) })}
      />
    </Can>
  );
}
