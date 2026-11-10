'use client';

import { Archive, BookOpen, Clock3, Ellipsis, ExternalLink, GraduationCap, ListChecks, Pencil, Plus, School, Send } from 'lucide-react';
import { useCallback, useState } from 'react';

import { Can } from '@/auth/can';
import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { FilterSelect, SearchInput, Toolbar } from '@/components/common/toolbar';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import { Skeleton } from '@/components/ui/skeleton';
import type { LearningMaterial, MaterialKind, Subject } from '@/data/contracts';
import type { MaterialRow } from '@/data/mock/services/learning';
import { SUBJECTS, type MaterialFilter, VISIBLE_MATERIAL_KINDS } from '@/data/schemas/learning';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { useArchiveMaterial, useLearningMaterials } from '../hooks';
import { gradesLabel, KIND_ICONS, KIND_TONES } from '../lib/format';
import { AssignmentFormDialog } from './assignment-form-dialog';
import { MaterialFormDialog } from './material-form-dialog';

const GRADES = Array.from({ length: 11 }, (_, i) => i + 1);

const hostOf = (url: string) => {
  try {
    return new URL(url).hostname.replace(/^www\./, '');
  } catch {
    return url;
  }
};

type CardActions = { onAssign: (id: string) => void; onEdit: (m: LearningMaterial) => void; onArchive: (m: LearningMaterial) => void };

function MaterialCard({ material, onAssign, onEdit, onArchive }: { material: MaterialRow } & CardActions) {
  const { t, tc } = useI18n();
  const Icon = KIND_ICONS[material.kind];
  return (
    <Card className={cn('card-glow flex flex-col p-5 animate-fade-in', material.own && 'border-info/25')}>
      <div className="flex items-start justify-between gap-3">
        <span className={cn('flex h-11 w-11 items-center justify-center rounded-2xl ring-1 ring-inset', KIND_TONES[material.kind])}>
          <Icon className="h-5 w-5" />
        </span>
        <div className="flex items-center gap-1">
          <Badge variant={material.own ? 'info' : 'secondary'} size="sm" className="gap-1">
            {material.own && <School className="h-3 w-3" />}
            {t(`enums.materialKind.${material.kind}`)}
          </Badge>
          {material.own && material.canEdit && (
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button variant="ghost" size="icon-sm" aria-label={t('learning.materials.form.menu')}>
                  <Ellipsis />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end">
                <DropdownMenuItem onClick={() => onEdit(material)}>
                  <Pencil className="h-4 w-4" />
                  {t('common.edit')}
                </DropdownMenuItem>
                <DropdownMenuItem className="text-destructive focus:text-destructive" onClick={() => onArchive(material)}>
                  <Archive className="h-4 w-4" />
                  {t('learning.materials.form.archive')}
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          )}
        </div>
      </div>
      <h3 className="mt-4 line-clamp-2 font-semibold leading-snug">{material.title}</h3>
      <p className="mt-1 text-sm text-muted-foreground">
        {t(`enums.subject.${material.subject}`)}
        {material.own && material.byName ? ` · ${material.byName}` : ''}
      </p>
      {material.own && material.body && <p className="mt-2 line-clamp-3 whitespace-pre-line text-sm text-foreground/80">{material.body}</p>}
      {material.own && material.linkUrl && (
        <a
          href={material.linkUrl}
          target="_blank"
          rel="noopener noreferrer nofollow"
          className="mt-2 flex items-center gap-1 truncate text-xs font-medium text-primary hover:underline"
        >
          <ExternalLink className="h-3.5 w-3.5 shrink-0" />
          <span className="truncate">{hostOf(material.linkUrl)}</span>
        </a>
      )}
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
  const [formOpen, setFormOpen] = useState(false);
  const [editing, setEditing] = useState<LearningMaterial | null>(null);
  const [archiving, setArchiving] = useState<LearningMaterial | null>(null);
  const archive = useArchiveMaterial();
  const materials = useLearningMaterials(filter);
  const openForm = (m: LearningMaterial | null) => {
    setEditing(m);
    setFormOpen(true);
  };
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
          <MaterialCard key={m.id} material={m} onAssign={openAssign} onEdit={openForm} onArchive={setArchiving} />
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
          options={VISIBLE_MATERIAL_KINDS.map((k) => ({ value: k, label: t(`enums.materialKind.${k}`) }))}
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
        <Can perm="learning.assign">
          <Button onClick={() => openForm(null)}>
            <Plus />
            {t('learning.materials.form.add')}
          </Button>
        </Can>
      </Toolbar>
      {content()}
      <AssignmentFormDialog open={dialogOpen} onOpenChange={setDialogOpen} materialId={assignId} />
      <MaterialFormDialog open={formOpen} onOpenChange={setFormOpen} material={editing} />
      <ConfirmDialog
        open={archiving !== null}
        onOpenChange={(open) => !open && setArchiving(null)}
        title={t('learning.materials.form.archiveTitle')}
        description={t('learning.materials.form.archiveDescription', { title: archiving?.title ?? '' })}
        confirmLabel={t('learning.materials.form.archive')}
        destructive
        loading={archive.isPending}
        onConfirm={() => archiving && archive.mutate(archiving.id, { onSuccess: () => setArchiving(null) })}
      />
    </>
  );
}
