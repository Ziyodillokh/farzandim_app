'use client';

/**
 * Konkursni o'chirish tasdig'i — `DELETE /admin/olympiads/:id`.
 *
 * NEGA ALOHIDA OGOHLANTIRISH: Prisma sxemasida `OlympiadAttempt` va
 * `OlympiadQuestion` olympiadga `onDelete: Cascade` bilan bog'langan. Ya'ni
 * konkurs o'chirilsa bolalarning ISHLAGAN NATIJALARI ham yo'q bo'ladi va uni
 * qaytarib bo'lmaydi. Backend `remove()` da hech qanday tekshiruv yo'q —
 * shuning uchun tasdiqni shu yerda ko'rsatamiz.
 *
 * Yig'ilgan DON/XP saqlanadi: `XpEvent` olympiadga FK bilan bog'lanmagan
 * (faqat `relatedId`), balans esa `ChildProfile.donBalance` da turadi.
 *
 * Bola faqat `published` konkursni ko'radi, shuning uchun "ko'rinmasin"
 * uchun o'chirish SHART EMAS — arxivlash yetadi (natijalar saqlanadi).
 */

import { AlertTriangle, Loader2 } from 'lucide-react';

import {
  Dialog, DialogContent, DialogHeader, DialogTitle,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import type { Olympiad } from '@/types/api.types';

export function OlympiadDeleteDialog({
  olympiad,
  onOpenChange,
  onConfirm,
  pending,
}: {
  /** `null` — oyna yopiq. */
  olympiad: Olympiad | null;
  onOpenChange: (v: boolean) => void;
  onConfirm: () => void;
  pending: boolean;
}) {
  // Nechta bola ishlagani ro'yxat javobida allaqachon bor
  // (`participantCount`) — alohida so'rov kerak emas.
  const count = olympiad?.participantCount ?? 0;

  return (
    <Dialog open={olympiad !== null} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <AlertTriangle className="h-5 w-5 text-destructive" />
            Konkursni o&apos;chirish
          </DialogTitle>
        </DialogHeader>

        <div className="space-y-3 py-2 text-sm">
          <p>
            <span className="font-semibold">{olympiad?.title}</span> butunlay
            o&apos;chiriladi. Bu amalni qaytarib bo&apos;lmaydi.
          </p>

          {count > 0 ? (
            <div className="rounded-lg border border-destructive/40 bg-destructive/10 px-3 py-2.5">
              <p className="font-medium text-destructive">
                {count} ta bola bu konkursni ishlagan.
              </p>
              <p className="mt-1 text-muted-foreground">
                Ularning natijalari va javoblari ham o&apos;chadi. Yig&apos;ilgan
                DON bolalarda saqlanib qoladi.
              </p>
            </div>
          ) : (
            <p className="text-muted-foreground">
              Bu konkursni hali hech kim ishlamagan.
            </p>
          )}

          <p className="text-muted-foreground">
            Faqat bolalarga ko&apos;rinmasin desangiz, o&apos;chirish o&apos;rniga{' '}
            <span className="font-medium text-foreground">Arxivlash</span>{' '}
            ishlating — natijalar saqlanadi.
          </p>
        </div>

        <div className="flex justify-end gap-2">
          <Button variant="ghost" onClick={() => onOpenChange(false)}>
            Bekor qilish
          </Button>
          <Button variant="destructive" onClick={onConfirm} disabled={pending}>
            {pending && <Loader2 className="h-4 w-4 animate-spin" />}
            O&apos;chirish
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  );
}
