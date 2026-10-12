'use client';

import { ArrowRight, FilePlus2, FileX2, ScrollText } from 'lucide-react';
import { useMemo, useState, type ReactNode } from 'react';

import { Badge } from '@/components/ui/badge';
import { Label } from '@/components/ui/label';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle } from '@/components/ui/sheet';
import { Switch } from '@/components/ui/switch';
import type { AuditLog } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { auditShape, diffValues, type DiffRow } from '../diff';
import { DiffValue, FieldLabel } from './diff-value';

function Meta({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="min-w-0">
      <dt className="text-2xs font-semibold uppercase tracking-wide text-muted-foreground">{label}</dt>
      <dd className="mt-0.5 truncate text-sm">{children}</dd>
    </div>
  );
}

function ChangeRow({ row, shape }: { row: DiffRow; shape: ReturnType<typeof auditShape> }) {
  const showBefore = shape !== 'create';
  const showAfter = shape !== 'delete';
  return (
    <li className={cn('rounded-lg border p-3', row.kind === 'same' && 'opacity-60')}>
      <FieldLabel field={row.field} />
      <div className="mt-1.5 flex flex-wrap items-center gap-2">
        {showBefore && (
          <DiffValue
            value={row.before}
            className={cn('rounded-md px-2 py-0.5', row.kind !== 'same' && showAfter && 'bg-destructive/10 text-destructive line-through decoration-destructive/40')}
          />
        )}
        {showBefore && showAfter && row.kind !== 'same' && <ArrowRight className="h-3.5 w-3.5 shrink-0 text-muted-foreground" />}
        {showAfter && row.kind !== 'same' && (
          <DiffValue value={row.after} className={cn('rounded-md px-2 py-0.5', showBefore ? 'bg-success/10 text-success' : 'bg-muted')} />
        )}
      </div>
    </li>
  );
}

export function AuditDetailSheet({ entry, onOpenChange }: { entry: AuditLog | null; onOpenChange: (open: boolean) => void }) {
  const { t, formatDate, formatRelative } = useI18n();
  const [showUnchanged, setShowUnchanged] = useState(false);
  const shape = entry ? auditShape(entry.before, entry.after) : 'none';
  const rows = useMemo(() => (entry ? diffValues(entry.before, entry.after) : []), [entry]);
  const changed = rows.filter((r) => r.kind !== 'same');
  const visible = shape === 'update' && !showUnchanged ? changed : rows;

  return (
    <Sheet open={Boolean(entry)} onOpenChange={onOpenChange}>
      <SheetContent className="w-full p-0 sm:max-w-lg">
        {entry && (
          <>
            <SheetHeader className="pr-12">
              <SheetTitle className="leading-snug">{entry.summary}</SheetTitle>
              <SheetDescription className="flex flex-wrap items-center gap-2">
                <Badge variant="outline">{t(`enums.auditModule.${entry.module}`)}</Badge>
                <span>{formatRelative(entry.at)}</span>
              </SheetDescription>
            </SheetHeader>
            <ScrollArea className="flex-1">
              <div className="space-y-6 p-6">
                <dl className="grid grid-cols-2 gap-4 rounded-xl border bg-muted/30 p-4">
                  <Meta label={t('audit.detail.at')}>{formatDate(entry.at, 'd MMMM yyyy, HH:mm:ss')}</Meta>
                  <Meta label={t('audit.detail.actor')}>{entry.actorName}</Meta>
                  <Meta label={t('audit.detail.action')}>
                    <code className="text-xs">{entry.action}</code>
                  </Meta>
                  <Meta label={t('audit.detail.entity')}>
                    <code className="text-xs">{entry.entityId ?? '—'}</code>
                  </Meta>
                </dl>

                <section>
                  <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
                    <h3 className="flex items-center gap-2 text-sm font-semibold">
                      {shape === 'create' ? <FilePlus2 className="h-4 w-4 text-success" /> : shape === 'delete' ? <FileX2 className="h-4 w-4 text-destructive" /> : <ScrollText className="h-4 w-4 text-primary" />}
                      {shape === 'create' ? t('audit.detail.created') : shape === 'delete' ? t('audit.detail.deleted') : t('audit.detail.changes')}
                    </h3>
                    {shape === 'update' && (
                      <div className="flex items-center gap-2">
                        <Switch id="audit-unchanged" checked={showUnchanged} onCheckedChange={setShowUnchanged} />
                        <Label htmlFor="audit-unchanged" className="text-xs font-normal text-muted-foreground">
                          {t('audit.detail.showUnchanged')}
                        </Label>
                      </div>
                    )}
                  </div>
                  {shape === 'none' ? (
                    <p className="rounded-lg border border-dashed p-4 text-sm text-muted-foreground">{t('audit.detail.noChanges')}</p>
                  ) : (
                    <>
                      {shape === 'update' && (
                        <p className="mb-2 text-xs text-muted-foreground">
                          {changed.length > 0 ? t('audit.detail.changedCount', { count: changed.length }) : t('audit.detail.nothingChanged')}
                        </p>
                      )}
                      <ul className="space-y-2">
                        {visible.map((row) => (
                          <ChangeRow key={row.field} row={row} shape={shape} />
                        ))}
                      </ul>
                    </>
                  )}
                </section>
              </div>
            </ScrollArea>
          </>
        )}
      </SheetContent>
    </Sheet>
  );
}
