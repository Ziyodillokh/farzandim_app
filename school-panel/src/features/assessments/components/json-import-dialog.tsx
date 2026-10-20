'use client';

import { AlertCircle, FileJson } from 'lucide-react';
import { useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';

import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Textarea } from '@/components/ui/textarea';
import { ServiceError } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { useImportTest } from '../hooks';
import { psychErrorKey } from '../lib/labels';
import { viewHref } from './test-card';

/** Xato tafsiloti: maydon yo'li + tarjima (masalan, "items.3.correct — To'g'ri javobni belgilang"). */
function useErrorText(error: unknown): string | null {
  const { t } = useI18n();
  if (!error) return null;
  const key = psychErrorKey(error);
  if (!(error instanceof ServiceError) || error.code !== 'VALIDATION') return t(key);
  const [path = '', ...rest] = error.message.split(': ');
  const detail = rest.join(': ');
  const text = key !== 'errors.VALIDATION' ? t(key) : detail === 'Required' ? t('errors.form.required') : detail || t(key);
  return path && path !== 'file' && !path.includes(' ') ? `${path.replace(/^test\./, '')} — ${text}` : text;
}

export function JsonImportDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (open: boolean) => void }) {
  const { t } = useI18n();
  const router = useRouter();
  const importTest = useImportTest();
  const [text, setText] = useState('');
  const [fileName, setFileName] = useState('');
  const errorText = useErrorText(importTest.error);

  useEffect(() => {
    if (!open) return;
    setText('');
    setFileName('');
    importTest.reset();
    // eslint-disable-next-line react-hooks/exhaustive-deps -- faqat ochilganda tozalanadi
  }, [open]);

  const onFile = async (file: File | undefined) => {
    if (!file) return;
    setFileName(file.name);
    importTest.reset();
    setText(await file.text());
  };

  const run = () =>
    importTest.mutate(text, {
      onSuccess: (test) => {
        onOpenChange(false);
        router.push(viewHref(test.id, 'items'));
      },
    });

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>{t('assessments.importJson.title')}</DialogTitle>
          <DialogDescription>{t('assessments.importJson.hint')}</DialogDescription>
        </DialogHeader>
        <label className="flex cursor-pointer flex-col items-center gap-2 rounded-xl border-2 border-dashed border-border/70 p-6 text-center transition-colors hover:border-primary/50 hover:bg-primary/5">
          <FileJson className="h-8 w-8 text-primary" />
          <span className="text-sm font-medium">{fileName || t('assessments.importJson.choose')}</span>
          <input type="file" accept=".json,application/json" className="sr-only" data-testid="json-file" onChange={(e) => void onFile(e.target.files?.[0])} />
        </label>
        <Textarea
          value={text}
          onChange={(e) => {
            setText(e.target.value);
            setFileName('');
          }}
          rows={5}
          placeholder={t('assessments.importJson.paste')}
          className="font-mono text-xs"
          aria-label={t('assessments.importJson.paste')}
        />
        {errorText && (
          <div role="alert" className="flex items-start gap-2 rounded-xl bg-destructive/10 p-3 text-sm text-destructive ring-1 ring-inset ring-destructive/20">
            <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
            <span>
              <span className="font-semibold">{t('assessments.importJson.failed')}.</span> {errorText}
            </span>
          </div>
        )}
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button disabled={!text.trim()} loading={importTest.isPending} onClick={run}>
            {t('assessments.importJson.run')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
