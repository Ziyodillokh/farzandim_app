'use client';

import { FileUp } from 'lucide-react';
import { useEffect, useState, type ChangeEvent } from 'react';

import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import type { CardImportRow, CardImportSummary } from '@/data/contracts';
import { MAX_IMPORT_ROWS } from '@/data/schemas/cards';
import { useI18n } from '@/i18n';
import { formatCardNumber } from '@/lib/card-number';
import { parseCsv } from '@/lib/csv';
import { importRowsFromCsv } from '../batch-csv';
import { useImportCards } from '../batch-hooks';

const IMPORT_CODES = ['CARD_TAKEN', 'RESERVATION_NOT_FOUND', 'INVALID_UID', 'STUDENT_ARCHIVED'] as const;
type ImportCode = (typeof IMPORT_CODES)[number] | 'ERROR';
const importCode = (code: string | null): ImportCode => (IMPORT_CODES as readonly string[]).includes(code ?? '') ? (code as ImportCode) : 'ERROR';

/** Ta'minotchi fayli (kartaga bosilgan raqam ↔ chip UID): butun partiya bir yo'la bog'lanadi. */
export function ImportCardsDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (open: boolean) => void }) {
  const { t } = useI18n();
  const importCards = useImportCards();
  const [rows, setRows] = useState<CardImportRow[] | null>(null);
  const [fileError, setFileError] = useState<string | null>(null);
  const [summary, setSummary] = useState<CardImportSummary | null>(null);

  useEffect(() => {
    if (open) return;
    setRows(null);
    setFileError(null);
    setSummary(null);
  }, [open]);

  const onFile = async (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    setSummary(null);
    if (!file) return;
    const parsed = importRowsFromCsv(parseCsv(await file.text()));
    setRows(parsed);
    if (parsed.length === 0) setFileError(t('cards.batch.importEmpty'));
    else if (parsed.length > MAX_IMPORT_ROWS) setFileError(t('cards.batch.importTooMany', { max: MAX_IMPORT_ROWS }));
    else setFileError(null);
  };

  const failed = summary?.results.filter((r) => !r.ok) ?? [];
  const canRun = Boolean(rows?.length) && !fileError && !summary;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-xl">
        <DialogHeader>
          <DialogTitle>{t('cards.batch.importTitle')}</DialogTitle>
          <DialogDescription>{t('cards.batch.importText')}</DialogDescription>
        </DialogHeader>

        <label className="flex cursor-pointer items-center gap-3 rounded-xl border border-dashed px-4 py-3 text-sm transition-colors hover:bg-muted/60">
          <FileUp className="h-5 w-5 text-primary" />
          <span className="font-medium">{t('cards.batch.importFile')}</span>
          <input type="file" accept=".csv,.txt,text/csv" className="sr-only" onChange={(e) => void onFile(e)} aria-label={t('cards.batch.importFile')} />
        </label>
        {rows && !fileError && !summary && <p className="text-sm text-muted-foreground">{t('cards.batch.importRows', { count: rows.length })}</p>}
        {fileError && <p className="text-sm font-medium text-destructive">{fileError}</p>}

        {summary && (
          <div className="space-y-2" role="status">
            <p className="text-sm font-semibold">{t('cards.batch.importDone', { bound: summary.bound, failed: failed.length })}</p>
            {failed.length > 0 && (
              <ul className="max-h-48 space-y-1 overflow-y-auto rounded-xl bg-destructive/5 p-3 text-sm">
                {failed.map((r, i) => (
                  <li key={`${r.number}-${i}`} className="flex gap-2">
                    <span className="font-mono tabular-nums">{formatCardNumber(r.number) || '—'}</span>
                    <span className="text-destructive">{t(`cards.batch.importCodes.${importCode(r.code)}`)}</span>
                  </li>
                ))}
              </ul>
            )}
          </div>
        )}

        <DialogFooter>
          <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
            {t('common.close')}
          </Button>
          <Button type="button" disabled={!canRun} loading={importCards.isPending} onClick={() => rows && importCards.mutate({ rows }, { onSuccess: setSummary })}>
            {t('cards.batch.importRun')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
