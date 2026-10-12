'use client';

import { RotateCcw, Ruler, Save } from 'lucide-react';
import { useEffect, useState } from 'react';
import { toast } from 'sonner';

import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { SectionCard } from '@/components/common/section-card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import type { AgeBand, NormRow, PsychNorms, PsychScale } from '@/data/contracts';
import type { PsychTestDetail } from '@/data/mock/services/assessments';
import { AGE_BAND_KEYS } from '@/data/schemas/assessments';
import { TILE } from '@/features/dashboard/lib/tile';
import { useI18n } from '@/i18n';
import { maxRaw, minRaw } from '@/lib/psych/scoring';
import { cn } from '@/lib/utils';
import { useUpdateNorms } from '../../hooks';

type Cell = { mean: string; sd: string };
type Draft = Record<string, Record<AgeBand, Cell>>;

function toDraft(scales: readonly PsychScale[], norms: PsychNorms): Draft {
  return Object.fromEntries(
    scales.map((s) => {
      const rows = norms[s.key] ?? [];
      const cells = Object.fromEntries(
        AGE_BAND_KEYS.map((band) => {
          const row = rows.find((r) => r.band === band);
          return [band, { mean: row ? String(row.mean) : '', sd: row ? String(row.sd) : '' }];
        }),
      ) as Record<AgeBand, Cell>;
      return [s.key, cells];
    }),
  );
}

function fromDraft(draft: Draft): PsychNorms {
  const out: PsychNorms = {};
  for (const [key, cells] of Object.entries(draft)) {
    const rows: NormRow[] = AGE_BAND_KEYS.flatMap((band) => {
      const c = cells[band];
      if (!c || c.mean.trim() === '' || c.sd.trim() === '') return [];
      return [{ band, mean: Number(c.mean.replace(',', '.')), sd: Number(c.sd.replace(',', '.')) }];
    });
    if (rows.length) out[key] = rows;
  }
  return out;
}

function ScaleNorms({
  scale,
  test,
  cells,
  defaults,
  disabled,
  onChange,
}: {
  scale: PsychScale;
  test: PsychTestDetail;
  cells: Record<AgeBand, Cell>;
  defaults: NormRow[] | undefined;
  disabled: boolean;
  onChange: (band: AgeBand, field: keyof Cell, value: string) => void;
}) {
  const { t, locale } = useI18n();
  const range = test.items.length ? { min: minRaw(test, scale.key), max: maxRaw(test, scale.key) } : { min: 0, max: 1000 };
  return (
    <div className={cn(TILE, 'overflow-hidden')}>
      <div className="flex flex-wrap items-center justify-between gap-2 border-b border-border/50 px-4 py-3 dark:border-white/[0.06]">
        <span className="font-semibold">{scale.label[locale]}</span>
        <span className="text-xs tabular-nums text-muted-foreground">{t('assessments.norms.range', range)}</span>
      </div>
      {scale.display === 'RAW' ? (
        <p className="px-4 py-3 text-sm text-muted-foreground">{t('assessments.norms.rawScale')}</p>
      ) : (
        <table className="w-full text-sm">
          <thead className="text-xs text-muted-foreground">
            <tr>
              <th className="px-4 py-2 text-left font-medium">{t('assessments.norms.band')}</th>
              <th className="px-2 py-2 text-left font-medium">{t('assessments.norms.mean')}</th>
              <th className="px-4 py-2 text-left font-medium">{t('assessments.norms.sd')}</th>
            </tr>
          </thead>
          <tbody>
            {AGE_BAND_KEYS.map((band) => {
              const d = defaults?.find((r) => r.band === band);
              return (
                <tr key={band} className="border-t border-border/40 dark:border-white/[0.05]">
                  <td className="whitespace-nowrap px-4 py-1.5 font-medium">{t(`enums.ageBand.${band}`)}</td>
                  <td className="px-2 py-1.5">
                    <Input
                      inputMode="decimal"
                      className="h-8 w-24 tabular-nums"
                      value={cells[band].mean}
                      placeholder={d ? String(d.mean) : '—'}
                      disabled={disabled}
                      aria-label={`${scale.label[locale]} · ${t(`enums.ageBand.${band}`)} · ${t('assessments.norms.mean')}`}
                      onChange={(e) => onChange(band, 'mean', e.target.value)}
                    />
                  </td>
                  <td className="px-4 py-1.5">
                    <Input
                      inputMode="decimal"
                      className="h-8 w-24 tabular-nums"
                      value={cells[band].sd}
                      placeholder={d ? String(d.sd) : '—'}
                      disabled={disabled}
                      aria-label={`${scale.label[locale]} · ${t(`enums.ageBand.${band}`)} · ${t('assessments.norms.sd')}`}
                      onChange={(e) => onChange(band, 'sd', e.target.value)}
                    />
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      )}
    </div>
  );
}

/** Me'yorlar: o'rtacha va sd — shkala × yosh bandi. Shablonda "standartga qaytarish". */
export function NormsTable({ test }: { test: PsychTestDetail }) {
  const { t } = useI18n();
  const update = useUpdateNorms();
  const [draft, setDraft] = useState<Draft>(() => toDraft(test.scales, test.norms));
  const [restoreOpen, setRestoreOpen] = useState(false);
  const disabled = test.status === 'ARCHIVED';
  const template = test.source === 'TEMPLATE';

  useEffect(() => {
    setDraft(toDraft(test.scales, test.norms));
  }, [test.scales, test.norms]);

  const change = (key: string, band: AgeBand, field: keyof Cell, value: string) =>
    setDraft((prev) => {
      const cells = prev[key];
      if (!cells) return prev;
      return { ...prev, [key]: { ...cells, [band]: { ...cells[band], [field]: value } } };
    });

  const save = () => update.mutate({ id: test.id, norms: fromDraft(draft) }, { onSuccess: () => toast.success(t('assessments.norms.saved')) });
  const restore = () =>
    update.mutate(
      { id: test.id, norms: null },
      {
        onSuccess: () => {
          setRestoreOpen(false);
          toast.success(t('assessments.norms.restored'));
        },
      },
    );

  return (
    <SectionCard
      icon={<Ruler />}
      title={t('assessments.norms.title')}
      description={t('assessments.norms.hint')}
      actions={
        template && (
          <Badge variant={test.normsOverridden ? 'info' : 'secondary'}>{test.normsOverridden ? t('assessments.norms.overridden') : t('assessments.norms.defaults')}</Badge>
        )
      }
      bodyClassName="space-y-4 p-5"
    >
      {disabled && <p className="text-sm text-muted-foreground">{t('assessments.norms.readOnly')}</p>}
      <div className={cn('grid gap-4', test.scales.length > 1 ? 'xl:grid-cols-2' : 'max-w-2xl')}>
        {test.scales.map((s) => (
          <ScaleNorms
            key={s.key}
            scale={s}
            test={test}
            cells={draft[s.key] ?? toDraft([s], {})[s.key] ?? ({} as Record<AgeBand, Cell>)}
            defaults={test.defaultNorms?.[s.key]}
            disabled={disabled}
            onChange={(band, field, value) => change(s.key, band, field, value)}
          />
        ))}
      </div>
      <p className="text-xs text-muted-foreground">{t('assessments.norms.emptyHint')}</p>
      {!disabled && (
        <div className="flex flex-wrap justify-end gap-2">
          {template && test.normsOverridden && (
            <Button variant="outline" onClick={() => setRestoreOpen(true)}>
              <RotateCcw />
              {t('assessments.norms.restore')}
            </Button>
          )}
          <Button onClick={save} loading={update.isPending}>
            <Save />
            {t('assessments.norms.save')}
          </Button>
        </div>
      )}
      <ConfirmDialog
        open={restoreOpen}
        onOpenChange={setRestoreOpen}
        title={t('assessments.norms.restoreTitle')}
        description={t('assessments.norms.restoreDescription')}
        confirmLabel={t('assessments.norms.restore')}
        loading={update.isPending}
        onConfirm={restore}
      />
    </SectionCard>
  );
}
