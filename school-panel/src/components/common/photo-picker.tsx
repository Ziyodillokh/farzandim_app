'use client';

import { ImagePlus, Trash2 } from 'lucide-react';
import { useRef, useState } from 'react';
import { toast } from 'sonner';

import { Button } from '@/components/ui/button';
import { useI18n } from '@/i18n';
import { resizePhoto } from '@/lib/image-resize';

const MAX_FILE_BYTES = 8 * 1024 * 1024;
const ACCEPT = ['image/jpeg', 'image/png', 'image/webp'];

/** Rasm tanlash: tekshiradi, kvadrat qilib kichraytiradi va data URL'ni qaytaradi. */
export function PhotoPicker({
  inputId,
  hasPhoto,
  busy,
  onPick,
  onRemove,
}: {
  inputId: string;
  hasPhoto: boolean;
  busy?: boolean;
  onPick: (dataUrl: string) => void;
  onRemove?: () => void;
}) {
  const { t } = useI18n();
  const inputRef = useRef<HTMLInputElement>(null);
  const [processing, setProcessing] = useState(false);

  const handle = async (file: File | undefined) => {
    if (inputRef.current) inputRef.current.value = '';
    if (!file) return;
    if (!ACCEPT.includes(file.type)) return void toast.error(t('profile.photo.invalid'));
    if (file.size > MAX_FILE_BYTES) return void toast.error(t('profile.photo.tooLarge'));
    setProcessing(true);
    try {
      onPick(await resizePhoto(file));
    } catch {
      toast.error(t('profile.photo.failed'));
    } finally {
      setProcessing(false);
    }
  };

  return (
    <div className="flex flex-wrap items-center gap-2">
      <input
        ref={inputRef}
        id={inputId}
        type="file"
        accept={ACCEPT.join(',')}
        className="sr-only"
        onChange={(e) => void handle(e.target.files?.[0])}
      />
      <Button type="button" variant="outline" size="sm" loading={processing || busy} onClick={() => inputRef.current?.click()}>
        <ImagePlus />
        {hasPhoto ? t('profile.photo.replace') : t('profile.photo.upload')}
      </Button>
      {hasPhoto && onRemove && (
        <Button type="button" variant="ghost" size="sm" className="text-destructive hover:text-destructive" disabled={busy} onClick={onRemove}>
          <Trash2 />
          {t('profile.photo.remove')}
        </Button>
      )}
    </div>
  );
}
