'use client';

import { ImageUp, Trash2 } from 'lucide-react';
import { useRef, useState, type ChangeEvent } from 'react';
import { toast } from 'sonner';

import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { SchoolLogo } from '@/components/common/school-logo';
import { SectionCard } from '@/components/common/section-card';
import { Button } from '@/components/ui/button';
import type { School } from '@/data/contracts';
import { resizeLogo } from '@/data/mock/services/school';
import { useI18n } from '@/i18n';
import { useSetLogo } from '../hooks';

const ACCEPTED = ['image/png', 'image/jpeg', 'image/webp', 'image/svg+xml'];
const MAX_FILE_BYTES = 5 * 1024 * 1024;

/** Rasmni kichraytirish; o'qib bo'lmasa `null`. */
async function readLogo(file: File): Promise<string | null> {
  try {
    return await resizeLogo(file);
  } catch {
    return null;
  }
}

export function LogoCard({ school }: { school: School }) {
  const { t } = useI18n();
  const setLogo = useSetLogo();
  const inputRef = useRef<HTMLInputElement>(null);
  const [processing, setProcessing] = useState(false);
  const [confirmRemove, setConfirmRemove] = useState(false);

  const onFile = async (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    event.target.value = '';
    if (!file) return;
    if (!ACCEPTED.includes(file.type)) {
      toast.error(t('settings.logo.invalid'));
      return;
    }
    if (file.size > MAX_FILE_BYTES) {
      toast.error(t('settings.logo.tooLarge'));
      return;
    }
    setProcessing(true);
    try {
      const dataUrl = await readLogo(file);
      if (dataUrl) await setLogo.mutateAsync(dataUrl);
      else toast.error(t('settings.logo.failed'));
    } catch {
      // servis xatosi — toast hooks ichida
    } finally {
      setProcessing(false);
    }
  };

  const remove = async () => {
    try {
      await setLogo.mutateAsync(null);
      setConfirmRemove(false);
    } catch {
      // toast — hooks ichida
    }
  };

  const busy = processing || setLogo.isPending;

  return (
    <SectionCard title={t('settings.logo.title')} description={t('settings.logo.description')}>
      <div className="flex flex-col items-center gap-4 text-center">
        <div className="flex h-32 w-32 items-center justify-center rounded-2xl border border-dashed bg-muted/40 p-3">
          <SchoolLogo school={school} className="h-24 w-24 rounded-2xl text-xl" />
        </div>
        {!school.logo && <p className="max-w-xs text-xs text-muted-foreground">{t('settings.logo.placeholder')}</p>}
        <input ref={inputRef} type="file" accept={ACCEPTED.join(',')} className="sr-only" onChange={(e) => void onFile(e)} tabIndex={-1} aria-hidden />
        <div className="flex flex-wrap justify-center gap-2">
          <Button variant={school.logo ? 'outline' : 'default'} onClick={() => inputRef.current?.click()} loading={busy}>
            {!busy && <ImageUp />}
            {school.logo ? t('settings.logo.replace') : t('settings.logo.upload')}
          </Button>
          {school.logo && (
            <Button variant="ghost" className="text-destructive hover:text-destructive" onClick={() => setConfirmRemove(true)} disabled={busy}>
              <Trash2 />
              {t('settings.logo.remove')}
            </Button>
          )}
        </div>
      </div>
      <ConfirmDialog
        open={confirmRemove}
        onOpenChange={setConfirmRemove}
        title={t('settings.logo.removeTitle')}
        description={t('settings.logo.removeText')}
        confirmLabel={t('settings.logo.remove')}
        destructive
        loading={setLogo.isPending}
        onConfirm={() => void remove()}
      />
    </SectionCard>
  );
}
