'use client';

import { UserRound } from 'lucide-react';

import { PhotoPicker } from '@/components/common/photo-picker';
import { StaffAvatar } from '@/components/common/staff-avatar';
import { INNER_TILE } from '@/features/classes/styles';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

export type StaffPhotoFieldProps = {
  name: string;
  /** Joriy (yoki tanlangan) rasm; `null` — rasm yo'q. */
  photo: string | null;
  portrait: string | null;
  /** Saqlanmagan o'zgarish bormi (forma saqlanganda qo'llanadi). */
  pending: boolean;
  busy: boolean;
  onPick: (dataUrl: string) => void;
  onRemove: () => void;
};

/** Xodim rasmi: katta ko'rinish + tanlash/olib tashlash (forma bilan birga saqlanadi). */
export function StaffPhotoField({ name, photo, portrait, pending, busy, onPick, onRemove }: StaffPhotoFieldProps) {
  const { t } = useI18n();
  return (
    <div className={cn('flex flex-col items-center gap-4 p-4 text-center sm:flex-row sm:text-left', INNER_TILE)}>
      {photo || portrait || name.trim() ? (
        <StaffAvatar name={name} photo={photo} portrait={portrait} size="xl" className="shadow-glass ring-4 ring-background" />
      ) : (
        <span className="flex h-24 w-24 shrink-0 items-center justify-center rounded-[1.75rem] bg-primary/10 text-primary shadow-glass ring-4 ring-background">
          <UserRound className="h-10 w-10" strokeWidth={1.5} />
        </span>
      )}
      <div className="min-w-0 space-y-2">
        <p className="text-sm font-semibold">{t('staff.form.photo')}</p>
        <p className="text-xs leading-relaxed text-muted-foreground">{photo ? t('profile.photo.hint') : t('profile.photo.portraitNote')}</p>
        <PhotoPicker inputId="staff-photo" hasPhoto={Boolean(photo)} busy={busy} onPick={onPick} onRemove={onRemove} />
        {pending && <p className="text-2xs font-medium text-primary">{t('staff.form.photoPending')}</p>}
      </div>
    </div>
  );
}
