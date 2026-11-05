'use client';

import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
import type { LearningClassOption } from '@/data/mock/services/learning';
import { TILE } from '@/features/dashboard/lib/tile';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

/**
 * Topshiriq sinflari: plitkalar. `fits` — sinf materialning yosh doirasiga mos kelmasa xira ko'rinadi
 * (yozma vazifada doira yo'q). Sinf rahbari uchun "hammasi / tozalash" tugmalari yo'q (faqat o'z sinfi).
 */
export function AssignmentClassPicker({
  classes,
  value,
  onChange,
  showBulkActions,
  fits,
}: {
  classes: readonly LearningClassOption[];
  value: readonly string[];
  onChange: (next: string[]) => void;
  showBulkActions: boolean;
  fits: (cls: LearningClassOption) => boolean;
}) {
  const { t } = useI18n();
  return (
    <div>
      {showBulkActions && (
        <div className="mb-2 flex gap-2">
          <Button type="button" variant="ghost" size="sm" onClick={() => onChange(classes.filter(fits).map((c) => c.id))}>
            {t('learning.assignments.selectAll')}
          </Button>
          <Button type="button" variant="ghost" size="sm" onClick={() => onChange([])}>
            {t('learning.assignments.clear')}
          </Button>
        </div>
      )}
      <div className="grid grid-cols-3 gap-2 sm:grid-cols-6">
        {classes.map((c) => {
          const checked = value.includes(c.id);
          return (
            <label
              key={c.id}
              className={cn(TILE, 'flex cursor-pointer items-center gap-2 px-2.5 py-2 text-sm transition-colors', checked && 'bg-primary/[0.07] ring-primary/40 dark:bg-primary/[0.12]', !fits(c) && 'opacity-60')}
            >
              <Checkbox checked={checked} onCheckedChange={(on) => onChange(on === true ? [...value, c.id] : value.filter((x) => x !== c.id))} />
              {c.name}
            </label>
          );
        })}
      </div>
    </div>
  );
}
