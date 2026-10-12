'use client';

import { AlertCircle, Download, FileUp, Info } from 'lucide-react';
import { useEffect, useState } from 'react';

import { Badge, type BadgeProps } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { ScrollArea } from '@/components/ui/scroll-area';
import type { CsvPreview, CsvPreviewRow, CsvRowStatus } from '@/data/mock/services/assessments';
import { TILE } from '@/features/dashboard/lib/tile';
import { useI18n } from '@/i18n';
import { downloadCsv } from '@/lib/csv';
import { cn } from '@/lib/utils';
import { useCsvPreview, useImportResultsCsv } from '../hooks';
import { psychErrorKey } from '../lib/labels';

const STATUS_VARIANT: Record<CsvRowStatus, NonNullable<BadgeProps['variant']>> = { OK: 'success', ERROR: 'destructive', DUPLICATE: 'warning' };
const STATUSES: readonly CsvRowStatus[] = ['OK', 'ERROR', 'DUPLICATE'];
const PREVIEW_LIMIT = 200;
const TEMPLATE = [
  ['studentCode', 'test', 'date', 'raw', 'scale:memory'],
  ['P-1234', 'tpl-logic', '2026-09-28', '11', ''],
  ['P-5678', 'tpl-attention', '28.09.2026', '5', '6'],
  ['P-1234', 'Qog\'ozdagi mantiq testi', '2026-05-14', '42', ''],
];

function rawText(row: CsvPreviewRow): string {
  return Object.values(row.raw).join(' / ') || '—';
}

function PreviewTable({ preview }: { preview: CsvPreview }) {
  const { t } = useI18n();
  return (
    <ScrollArea className={cn(TILE, 'h-64')}>
      <table className="w-full text-left text-xs">
        <thead className="sticky top-0 bg-background/90 text-muted-foreground backdrop-blur">
          <tr>
            <th className="px-3 py-2 font-medium">{t('assessments.csv.columns.line')}</th>
            <th className="px-3 py-2 font-medium">{t('assessments.csv.columns.student')}</th>
            <th className="px-3 py-2 font-medium">{t('assessments.csv.columns.test')}</th>
            <th className="px-3 py-2 font-medium">{t('assessments.csv.columns.raw')}</th>
            <th className="px-3 py-2 font-medium">{t('assessments.csv.columns.status')}</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-border/50 dark:divide-white/[0.06]">
          {preview.rows.slice(0, PREVIEW_LIMIT).map((r) => (
            <tr key={r.line} className="align-top">
              <td className="px-3 py-2 tabular-nums text-muted-foreground">{r.line}</td>
              <td className="px-3 py-2">
                <span className="font-medium">{r.studentName ?? r.studentCode}</span>
                {r.className && <span className="ml-1 text-muted-foreground">· {r.className}</span>}
              </td>
              <td className="px-3 py-2">
                {r.testTitle ?? r.test}
                {r.date && <span className="block text-muted-foreground tabular-nums">{r.date}</span>}
              </td>
              <td className="px-3 py-2 tabular-nums">{rawText(r)}</td>
              <td className="px-3 py-2">
                <Badge variant={STATUS_VARIANT[r.status]} size="sm">
                  {t(`assessments.csv.status.${r.status}`)}
                </Badge>
                {r.reason && <span className="mt-1 block text-muted-foreground">{t(`assessments.csv.reasons.${r.reason}`)}</span>}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </ScrollArea>
  );
}

/** Natijalarni CSV'dan import qilish: oldindan ko'rish (har qator holati), xatolar hisoboti, faqat OK qatorlar. */
export function CsvImportDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (open: boolean) => void }) {
  const { t } = useI18n();
  const preview = useCsvPreview();
  const run = useImportResultsCsv();
  const [text, setText] = useState('');
  const [fileName, setFileName] = useState('');
  const data = preview.data;

  useEffect(() => {
    if (!open) return;
    setText('');
    setFileName('');
    preview.reset();
    // eslint-disable-next-line react-hooks/exhaustive-deps -- faqat ochilganda tozalanadi
  }, [open]);

  const onFile = async (file: File | undefined) => {
    if (!file) return;
    const content = await file.text();
    setFileName(file.name);
    setText(content);
    preview.mutate(content);
  };

  const errorReport = () => {
    const rows = (data?.rows ?? []).filter((r) => r.status !== 'OK');
    downloadCsv(t('assessments.csv.reportFile'), rows, [
      { header: t('assessments.csv.columns.line'), value: (r) => r.line },
      { header: 'studentCode', value: (r) => r.studentCode },
      { header: 'test', value: (r) => r.test },
      { header: 'date', value: (r) => r.date ?? '' },
      { header: t('assessments.csv.columns.status'), value: (r) => t(`assessments.csv.status.${r.status}`) },
      { header: t('assessments.csv.columns.reason'), value: (r) => (r.reason ? t(`assessments.csv.reasons.${r.reason}`) : '') },
    ]);
  };

  const template = () => downloadCsv('parvoz-natijalar-namuna', TEMPLATE.slice(1), TEMPLATE[0]?.map((header, i) => ({ header, value: (row: string[]) => row[i] ?? '' })) ?? []);
  const ok = data?.counts.OK ?? 0;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[92vh] overflow-y-auto sm:max-w-2xl">
        <DialogHeader>
          <DialogTitle>{t('assessments.csv.title')}</DialogTitle>
          <DialogDescription>{t('assessments.csv.hint')}</DialogDescription>
        </DialogHeader>
        <label className="flex cursor-pointer flex-col items-center gap-2 rounded-xl border-2 border-dashed border-border/70 p-6 text-center transition-colors hover:border-primary/50 hover:bg-primary/5">
          <FileUp className="h-8 w-8 text-primary" />
          <span className="text-sm font-medium">{preview.isPending ? t('assessments.csv.checking') : fileName || t('assessments.csv.choose')}</span>
          <input type="file" accept=".csv,text/csv" className="sr-only" data-testid="csv-file" onChange={(e) => void onFile(e.target.files?.[0])} />
        </label>
        <Button variant="link" className="h-auto justify-start p-0" onClick={template}>
          <Download />
          {t('assessments.csv.template')}
        </Button>

        {preview.error && (
          <div role="alert" className="flex items-start gap-2 rounded-xl bg-destructive/10 p-3 text-sm text-destructive ring-1 ring-inset ring-destructive/20">
            <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
            {t(psychErrorKey(preview.error))}
          </div>
        )}

        {data && (
          <div className="space-y-3">
            <div className="flex flex-wrap items-center gap-2">
              {STATUSES.map((s) => (
                <Badge key={s} variant={STATUS_VARIANT[s]}>
                  {t(`assessments.csv.counts.${s}`, { count: data.counts[s] })}
                </Badge>
              ))}
              {data.counts.ERROR + data.counts.DUPLICATE > 0 && (
                <Button variant="ghost" size="sm" className="ml-auto" onClick={errorReport}>
                  <Download />
                  {t('assessments.csv.errorReport')}
                </Button>
              )}
            </div>
            {data.newTests.length > 0 && (
              <p className="flex items-start gap-2 rounded-xl bg-primary/[0.06] p-3 text-xs ring-1 ring-inset ring-primary/15">
                <Info className="mt-0.5 h-3.5 w-3.5 shrink-0 text-primary" />
                {t('assessments.csv.newTests', { names: data.newTests.join(', ') })}
              </p>
            )}
            <PreviewTable preview={data} />
          </div>
        )}

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button disabled={ok === 0 || !text} loading={run.isPending} onClick={() => run.mutate(text, { onSuccess: () => onOpenChange(false) })}>
            {t('assessments.csv.run', { count: ok })}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
