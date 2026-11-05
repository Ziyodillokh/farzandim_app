'use client';

import { ChevronLeft, ChevronRight, ImageOff, RotateCw } from 'lucide-react';
import { type KeyboardEvent, useState } from 'react';

import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogTitle } from '@/components/ui/dialog';
import type { SubmissionPhoto } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

/**
 * Rasm: yuklanmasa (masalan, imzolangan havola muddati o'tgan) — o'rniga xabar va «Qayta yuklash».
 * `key={url}` bilan ishlatiladi: havola yangilansa, xato holati tozalanadi.
 */
function PhotoImage({ photo, alt, className, onReload }: { photo: SubmissionPhoto; alt: string; className?: string; onReload?: () => void }) {
  const { t } = useI18n();
  const [failed, setFailed] = useState(false);
  if (failed) {
    return (
      <div role="img" aria-label={alt} className={cn('flex flex-col items-center justify-center gap-2 bg-muted/60 p-3 text-center text-xs text-muted-foreground', className)}>
        <ImageOff className="h-6 w-6" aria-hidden />
        <span>{t('learning.submissions.gallery.loadFailed')}</span>
        {onReload && (
          <Button type="button" size="sm" variant="outline" onClick={onReload}>
            <RotateCw />
            {t('learning.submissions.gallery.reload')}
          </Button>
        )}
      </div>
    );
  }
  return (
    // Imzolangan tashqi/data URL — Next tasvir optimizatsiyasi (statik eksport) kerak emas.
    // eslint-disable-next-line @next/next/no-img-element
    <img src={photo.url} alt={alt} loading="lazy" onError={() => setFailed(true)} className={className} />
  );
}

/**
 * Bola yuborgan rasmlar: ko'rsatkichlar (thumbnail) va bosilganda katta ko'rinish
 * (chap/o'ng strelka, Esc — yopish, fokus qaytariladi).
 */
export function PhotoGallery({ photos, studentName, onReload }: { photos: readonly SubmissionPhoto[]; studentName: string; onReload?: () => void }) {
  const { t } = useI18n();
  const [openIndex, setOpenIndex] = useState<number | null>(null);
  const total = photos.length;
  const current = openIndex === null ? undefined : photos[openIndex];

  const go = (delta: number) => setOpenIndex((i) => (i === null || total === 0 ? null : (i + delta + total) % total));
  const onKeyDown = (event: KeyboardEvent) => {
    if (event.key === 'ArrowLeft') {
      event.preventDefault();
      go(-1);
    } else if (event.key === 'ArrowRight') {
      event.preventDefault();
      go(1);
    }
  };
  const altOf = (n: number) => t('learning.submissions.gallery.alt', { name: studentName, n });

  return (
    <>
      <ul className="grid grid-cols-2 gap-3 sm:grid-cols-3">
        {photos.map((photo, i) => (
          <li key={photo.id}>
            <button
              type="button"
              onClick={() => setOpenIndex(i)}
              aria-label={t('learning.submissions.gallery.open', { n: i + 1, total })}
              className="group block w-full overflow-hidden rounded-xl ring-1 ring-inset ring-border/60 transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
            >
              <PhotoImage key={photo.url} photo={photo} alt={altOf(i + 1)} onReload={onReload} className="aspect-[3/4] w-full object-cover transition-transform group-hover:scale-[1.02]" />
            </button>
          </li>
        ))}
      </ul>

      <Dialog open={openIndex !== null} onOpenChange={(open) => !open && setOpenIndex(null)}>
        <DialogContent className="max-w-3xl gap-3 p-4" onKeyDown={onKeyDown}>
          <DialogTitle className="pr-8 text-base">{t('learning.submissions.gallery.title', { name: studentName, n: (openIndex ?? 0) + 1, total })}</DialogTitle>
          <DialogDescription className="sr-only">{t('learning.submissions.gallery.description')}</DialogDescription>
          <div className="relative flex items-center justify-center">
            {current && (
              <PhotoImage
                key={current.url}
                photo={current}
                alt={altOf((openIndex ?? 0) + 1)}
                onReload={onReload}
                className="max-h-[70vh] w-auto max-w-full rounded-xl object-contain"
              />
            )}
            {total > 1 && (
              <>
                <Button type="button" variant="outline" size="icon" className="absolute left-1 top-1/2 -translate-y-1/2 rounded-full" onClick={() => go(-1)} aria-label={t('learning.submissions.gallery.prev')}>
                  <ChevronLeft />
                </Button>
                <Button type="button" variant="outline" size="icon" className="absolute right-1 top-1/2 -translate-y-1/2 rounded-full" onClick={() => go(1)} aria-label={t('learning.submissions.gallery.next')}>
                  <ChevronRight />
                </Button>
              </>
            )}
          </div>
        </DialogContent>
      </Dialog>
    </>
  );
}
