'use client';

import { Nfc, ShieldCheck } from 'lucide-react';
import { useEffect, useState } from 'react';

import { FormField } from '@/components/common/form-field';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import type { StudentRow } from '@/data/mock/services/students';
import { cardAssignSchema } from '@/data/schemas/cards';
import { StudentPicker } from '@/features/attendance/components/student-picker';
import { useI18n } from '@/i18n';
import { useAssignCard } from '../hooks';
import { type CardRead, type NfcState, useNfcReader } from '../nfc';

/** Kartadagi manzilda NTAG 424 DNA imzolangan kodi bormi (server baribir o'zi tekshiradi). */
const SIGNED_URL = /[?&](p|picc_data|e)=[0-9a-f]{32}(&|$)/i;

const NFC_NOTE: Partial<Record<NfcState, 'cards.dialog.unsupported' | 'cards.dialog.denied' | 'cards.dialog.failed' | 'cards.dialog.reading'>> = {
  unsupported: 'cards.dialog.unsupported',
  denied: 'cards.dialog.denied',
  error: 'cards.dialog.failed',
  scanning: 'cards.dialog.reading',
};

type FieldErrors = { studentId?: string; uid?: string; number?: string };

/** O'quvchiga karta biriktirish: NFC'li telefonda tegizib yoki USB o'qigich / qo'lda seriya raqami. */
export function AssignCardDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (open: boolean) => void }) {
  const { t } = useI18n();
  const assign = useAssignCard();
  const [student, setStudent] = useState<StudentRow | null>(null);
  const [uid, setUid] = useState('');
  const [url, setUrl] = useState<string | undefined>();
  const [number, setNumber] = useState('');
  const [errors, setErrors] = useState<FieldErrors>({});
  const nfc = useNfcReader((read: CardRead) => {
    setUid(read.uid ?? '');
    setUrl(read.url);
    setErrors((e) => ({ ...e, uid: undefined }));
  });
  const { stop } = nfc;

  useEffect(() => {
    if (open) return;
    stop();
    setStudent(null);
    setUid('');
    setUrl(undefined);
    setNumber('');
    setErrors({});
  }, [open, stop]);

  const submit = (event: React.FormEvent) => {
    event.preventDefault();
    const parsed = cardAssignSchema.safeParse({ studentId: student?.id ?? '', uid: uid || undefined, url, number: number || undefined });
    if (!parsed.success) {
      const next: FieldErrors = {};
      for (const issue of parsed.error.issues) next[issue.path[0] as keyof FieldErrors] ??= issue.message;
      setErrors(next);
      return;
    }
    assign.mutate(parsed.data, { onSuccess: () => onOpenChange(false) });
  };

  const note = NFC_NOTE[nfc.state];
  const signed = Boolean(url && SIGNED_URL.test(url));

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[92vh] overflow-y-auto sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>{t('cards.dialog.title')}</DialogTitle>
          <DialogDescription>{t('cards.dialog.description')}</DialogDescription>
        </DialogHeader>
        <form onSubmit={submit} className="grid gap-4" noValidate>
          <FormField label={t('cards.dialog.student')} error={errors.studentId ? { message: 'errors.form.required' } : undefined}>
            <StudentPicker value={student} onChange={setStudent} invalid={Boolean(errors.studentId)} />
          </FormField>

          <div className="grid gap-2">
            {nfc.state !== 'unsupported' && (
              <Button type="button" variant={nfc.state === 'scanning' ? 'soft' : 'outline'} onClick={() => void nfc.start()} loading={nfc.state === 'starting'}>
                <Nfc />
                {t('cards.dialog.read')}
              </Button>
            )}
            {note && <p className="text-xs text-muted-foreground">{t(note)}</p>}
          </div>

          <FormField label={t('cards.dialog.uid')} htmlFor="card-uid" error={errors.uid ? { message: errors.uid } : undefined} hint={t('cards.dialog.uidHint')}>
            <Input
              id="card-uid"
              value={uid}
              autoComplete="off"
              spellCheck={false}
              className="font-mono"
              placeholder="04:A1:B2:C3:D4:E5:F6"
              onChange={(e) => {
                setUid(e.target.value);
                setUrl(undefined);
              }}
            />
          </FormField>
          {signed && (
            <Badge variant="success" className="w-fit gap-1.5">
              <ShieldCheck className="h-3.5 w-3.5" />
              {t('cards.dialog.protected')}
            </Badge>
          )}

          <FormField label={t('cards.dialog.number')} htmlFor="card-number" error={errors.number ? { message: errors.number } : undefined} hint={t('cards.dialog.numberHint')}>
            <Input id="card-number" value={number} autoComplete="off" placeholder="K-000124" onChange={(e) => setNumber(e.target.value)} />
          </FormField>

          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" loading={assign.isPending}>
              {t('cards.dialog.submit')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
