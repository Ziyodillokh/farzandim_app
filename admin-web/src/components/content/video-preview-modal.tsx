'use client';

import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from '@/components/ui/dialog';
import { youtubeId } from '@/lib/youtube';
import type { Video } from '@/types/api.types';

// Admin o'zi qo'shgan videoni panelda ko'rib tekshirishi uchun preview.
// YouTube havolasi -> embed iframe; to'g'ridan-to'g'ri .mp4 -> HTML5 video.
export function VideoPreviewModal({
  video,
  open,
  onOpenChange,
}: {
  video: Video | null;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const ytId = video ? youtubeId(video.url) : null;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-2xl">
        <DialogHeader>
          <DialogTitle className="line-clamp-1">
            {video?.title ?? 'Video'}
          </DialogTitle>
          <DialogDescription className="sr-only">
            Video ko&apos;rish
          </DialogDescription>
        </DialogHeader>

        {video && (
          <div className="aspect-video w-full overflow-hidden rounded-lg bg-black">
            {ytId ? (
              <iframe
                key={ytId}
                className="h-full w-full"
                src={`https://www.youtube.com/embed/${ytId}`}
                title={video.title}
                allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                allowFullScreen
              />
            ) : (
              // eslint-disable-next-line jsx-a11y/media-has-caption
              <video
                key={video.url}
                className="h-full w-full"
                src={video.url}
                controls
                autoPlay
              />
            )}
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
}
