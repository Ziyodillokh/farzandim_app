'use client';

import { BookOpen, Clock3, GraduationCap, ListChecks, Send } from 'lucide-react';
import { useCallback, useState } from 'react';

import { Can } from '@/auth/can';
import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { FilterSelect, SearchInput, Toolbar } from '@/components/common/toolbar';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import type { MaterialKind, Subject } from '@/data/contracts';
import type { MaterialRow } from '@/data/mock/services/learning';
import { MATERIAL_KINDS, SUBJECTS, type MaterialFilter } from '@/data/schemas/learning';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { useLearningMaterials } from '../hooks';
import { gradesLabel, KIND_ICONS, KIND_TONES } from '../lib/format';
import { AssignmentFormDialog } from './assignment-form-dialog';

const GRADES = Array.from({ length: 11 }, (_, i) => i + 1);

function MaterialCard({ material, onAssign }: { material: MaterialRow; onAssign: (id: string) => void }) {
  const { t, tc } = useI18n();
  const Icon = KIND_ICONS[material.kind];
  return (
    <Card className="card-glow flex flex-col p-5 animate-fade-in">
      <div className="flex items-start justify-between gap-3">
        <span className={cn('flex h-11 w-11 items-center justify-center rounded-2xl ring-1 ring-inset', KIND_TONES[material.kind])}>
          <Icon className="h-5 w-5" />
        </span>
        <Badge variant="secondary" size="sm">{t(`enums.materialKind.${material.kind}`)}</Badge>
      </div>
      <h3 className="mt-4 line-clamp-2 font-semibold leading-snug">{material.title}</h3>
      <p className="mt-1 text-sm text-muted-foreground">{t(`enums.subject.${material.subject}`)}</p>
      <div className="mb-5 mt-3 flex flex-wrap gap-x-4 gap-y-1.5 text-xs text-muted-foreground">
        <span className="flex items-center gap-1"><GraduationCap className="h-3.5 w-3.5" />{gradesLabel(t, material.grades)}</span>
        <span className="flex items-center gap-1"><Clock3 className="h-3.5 w-3.5" />{t('learning.materials.duration', { count: material.durationMin })}</span>
        {material.questions > 0 && (
          <span className="flex items-center gap-1"><ListChecks className="h-3.5 w-3.5" />{tc('learning.materials.questions', material.questions)}</span>
        )}
      </div>
      <div className="mt-auto flex items-center justify-between gap-2 border-t border-border/50 pt-4 dark:border-white/[0.06]">
        <span className={cn('text-xs', material.assignedClasses > 0 ? 'font-medium text-success' : 'text-muted-foreground')}>
          {material.assignedClasses > 0 ? tc('learning.materials.assignedTo', material.assignedClasses) : t('learning.materials.notAssigned')}
        </span>
        <Can perm="learning.assign">
          <Button size="sm" variant="soft" onClick={() => onAssign(material.id)}>
            <Send />
            {t('learning.materials.assign')}
          </Button>
        </Can>
      </div>
    </Card>
  );
}

/** Materiallar katalogi: tur / fan / sinf bo'yicha filtr, kartochkalar. */
export function MaterialsTab() {
  const { t, tc } = useI18n();
  const [filter, setFilter] = useState<MaterialFilter>({});
  const [assignId, setAssignId] = useState<string | undefined>();
  const [dialogOpen, setDialogOpen] = useState(false);
  const materials = useLearningMaterials(filter);
  const onSearch = useCallback((search: string) => setFilter((f) => ({ ...f, search: search || undefined })), []);

  const openAssign = (id: string) => {
    setAssignId(id);
    setDialogOpen(true);
  };

  const content = () => {
    if (materials.error) return <ErrorState error={materials.error} onRetry={() => void materials.refetch()} />;
    if (materials.isLoading) {
      return (
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {Array.from({ length: 6 }, (_, i) => (
            <Skeleton key={i} className="h-56 rounded-2xl" />
          ))}
        </div>
      );
    }
    const items = materials.data ?? [];
    if (items.length === 0) {
      return (
        <Card>
          <EmptyState icon={<BookOpen />} title={t('learning.materials.empty')} description={t('learning.materials.emptyHint')} />
        </Card>
      );
    }
    return (
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
        {items.map((m) => (
          <MaterialCard key={m.id} material={m} onAssign={openAssign} />
        ))}
      </div>
    );
  };

  return (
    <>
      <Toolbar>
        <SearchInput value={filter.search ?? ''} onChange={onSearch} placeholder={t('learning.materials.searchPlaceholder')} />
        <FilterSelect
          value={filter.kind}
          onChange={(v) => setFilter((f) => ({ ...f, kind: v as MaterialKind | undefined }))}
          options={MATERIAL_KINDS.map((k) => ({ value: k, label: t(`enums.materialKind.${k}`) }))}
          allLabel={`${t('learning.materials.kind')}: ${t('common.all')}`}
          className="sm:w-44"
        />
        <FilterSelect
          value={filter.subject}
          onChange={(v) => setFilter((f) => ({ ...f, subject: v as Subject | undefined }))}
          options={SUBJECTS.map((s) => ({ value: s, label: t(`enums.subject.${s}`) }))}
          allLabel={`${t('learning.materials.subject')}: ${t('common.all')}`}
          className="sm:w-48"
        />
        <FilterSelect
          value={filter.grade === undefined ? undefined : String(filter.grade)}
          onChange={(v) => setFilter((f) => ({ ...f, grade: v ? Number(v) : undefined }))}
          options={GRADES.map((g) => ({ value: String(g), label: t('learning.materials.gradeOption', { grade: g }) }))}
          allLabel={`${t('learning.materials.grade')}: ${t('common.all')}`}
          className="sm:w-40"
        />
        {materials.data && (
          <span className="ml-auto text-sm text-muted-foreground">{tc('learning.materials.count', materials.data.length)}</span>
        )}
      </Toolbar>
      {content()}
      <AssignmentFormDialog open={dialogOpen} onOpenChange={setDialogOpen} materialId={assignId} />
    </>
  );
}
