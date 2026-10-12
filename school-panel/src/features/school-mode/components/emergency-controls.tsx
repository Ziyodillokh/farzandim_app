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
      <div className="grid grid-cols-2 gap-2" role="radiogroup">
        {(['SCHOOL', 'CLASS'] as const).map((value) => (
          <button
            key={value}
            type="button"
            role="radio"
            aria-checked={scope === value}
            onClick={() => onScope(value)}
            className={cn(
              'rounded-lg border px-3 py-2.5 text-sm font-medium transition-colors',
              scope === value ? 'border-destructive bg-destructive/10 text-destructive' : 'hover:bg-accent',
            )}
          >
            {value === 'SCHOOL' ? t('schoolMode.emergency.scopeSchool') : t('schoolMode.emergency.scopeClass')}
          </button>
        ))}
      </div>
      {scope === 'CLASS' && (
        <div className="flex max-h-40 flex-wrap gap-1.5 overflow-y-auto rounded-lg border p-2">
          {classes.map((c) => {
            const on = selected.includes(c.classId);
            return (
              <button
                key={c.classId}
                type="button"
                aria-pressed={on}
                onClick={() => onToggle(c.classId)}
                className={cn(
                  'rounded-md border px-2.5 py-1 text-xs font-semibold tabular-nums transition-colors',
                  on ? 'border-destructive bg-destructive text-destructive-foreground' : 'hover:border-destructive/50',
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
export function EmergencyControls({ overview, inverted }: { overview: SchoolModeOverview | undefined; inverted: boolean }) {
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
        <Button size="lg" variant={inverted ? 'secondary' : 'outline'} onClick={() => setOpenOff(true)}>
          <Power />
          {t('schoolMode.emergency.restore')}
        </Button>
      )}
      {!schoolWide && (
        <Button size="lg" variant="destructive" className={cn(inverted && 'ring-2 ring-white/40')} onClick={() => setOpenOn(true)}>
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
