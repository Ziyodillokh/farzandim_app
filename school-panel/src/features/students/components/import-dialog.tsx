'use client';

import { useQueryClient } from '@tanstack/react-query';
import { FileUp } from 'lucide-react';
import { useState } from 'react';
import { toast } from 'sonner';

import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { api } from '@/data/api';
import { useI18n } from '@/i18n';
import { downloadCsv, parseCsv } from '@/lib/csv';

const TEMPLATE_ROWS = [
  ['Karimov', 'Aziz', 'Akmal o\'g\'li', '7-A', 'M', '2013-05-14', 'Karimova Malika', '+998 90 123 45 67'],
  ['Rasulova', 'Madina', 'Bobur qizi', '5-B', 'F', '2015-09-02', 'Rasulov Bobur', '+998 93 765 43 21'],
];

export function ImportDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (open: boolean) => void }) {
  const { t } = useI18n();
  const queryClient = useQueryClient();
  const [rows, setRows] = useState<string[][] | null>(null);
  const [fileName, setFileName] = useState('');
  const [running, setRunning] = useState(false);

  const onFile = async (file: File | undefined) => {
    if (!file) return;
    setFileName(file.name);
    const parsed = parseCsv(await file.text());
    setRows(parsed.slice(1));
  };

  const run = async () => {
    if (!rows) return;
    setRunning(true);
    try {
      const result = await api.students.importRows(rows);
      toast.success(t('students.import.result', { created: result.created, skipped: result.skipped.length }));
      void queryClient.invalidateQueries();
      onOpenChange(false);
      setRows(null);
      setFileName('');
    } finally {
      setRunning(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>{t('students.import.title')}</DialogTitle>
          <DialogDescription>{t('students.import.hint')}</DialogDescription>
        </DialogHeader>
        <label className="flex cursor-pointer flex-col items-center gap-2 rounded-xl border-2 border-dashed p-8 text-center transition-colors hover:border-primary/50 hover:bg-primary/5">
          <FileUp className="h-8 w-8 text-primary" />
          <span className="text-sm font-medium">{fileName || t('students.import.choose')}</span>
          {rows && <span className="text-xs text-muted-foreground">{t('common.total')}: {rows.length}</span>}
          <input type="file" accept=".csv,text/csv" className="sr-only" onChange={(e) => onFile(e.target.files?.[0])} />
        </label>
        <Button
          variant="link"
          className="h-auto justify-start p-0"
          onClick={() =>
            downloadCsv('parvoz-import-namuna', TEMPLATE_ROWS, [
              'Familiya',
              'Ism',
              'Otasining ismi',
              'Sinf',
              'Jinsi',
              'Tug\'ilgan sana',
              'Ota-ona',
              'Telefon',
            ].map((header, i) => ({ header, value: (row: string[]) => row[i] ?? '' })))
          }
        >
          {t('students.import.template')}
        </Button>
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button disabled={!rows?.length} loading={running} onClick={run}>
            {t('students.import.run')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
