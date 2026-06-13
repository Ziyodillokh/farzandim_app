'use client';

import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from '@/components/ui/dialog';
import { contentMediaUrl } from '@/lib/media';
import type { Audiobook } from '@/types/api.types';

// Admin o'zi yuklagan audiokitobni panelda eshitib tekshirishi uchun.
// Audio @Public proxy orqali oqadi (signed MinIO URL telefonga/brauzerga
// yetmaydi).
export function AudiobookPreviewModal({
  book,
  open,
  onOpenChange,
}: {
  book: Audiobook | null;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const audioUrl = book
    ? contentMediaUrl('audio', book.storageKey) ?? book.audioUrl
    : null;
  const coverUrl = book
    ? contentMediaUrl('thumb', book.thumbStorageKey) ?? book.thumbnail
    : null;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle className="line-clamp-1">
            {book?.title ?? 'Audiokitob'}
          </DialogTitle>
          <DialogDescription className="line-clamp-1">
            {book?.author ?? ''}
          </DialogDescription>
        </DialogHeader>

        {book && (
          <div className="flex flex-col items-center gap-4">
            <div className="h-40 w-40 overflow-hidden rounded-lg bg-muted">
              {coverUrl ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={coverUrl}
                  alt={book.title}
                  className="h-full w-full object-cover"
                />
              ) : null}
            </div>
            {audioUrl ? (
              // eslint-disable-next-line jsx-a11y/media-has-caption
              <audio className="w-full" src={audioUrl} controls autoPlay />
            ) : (
              <p className="text-sm text-muted-foreground">Audio topilmadi</p>
            )}
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
}
