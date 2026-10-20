'use client';

import { AtSign, Briefcase, Camera, ChevronDown, KeyRound, Phone } from 'lucide-react';
import { useState } from 'react';

import { PhotoPicker } from '@/components/common/photo-picker';
import { StaffAvatar } from '@/components/common/staff-avatar';
import { Badge } from '@/components/ui/badge';
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Skeleton } from '@/components/ui/skeleton';
import { isHttpMode } from '@/data/source';
import { PasswordChangeForm } from '@/features/auth/components/password-change-form';
import { useI18n } from '@/i18n';
import { useMe, useSetStaffPhoto } from '../hooks';

const INPUT_ID = 'profile-photo-input';

function Row({ icon, label, value }: { icon: React.ReactNode; label: string; value: string }) {
  return (
    <div className="flex items-center gap-3 rounded-xl bg-primary/[0.04] px-3 py-2.5 ring-1 ring-inset ring-border/50 dark:bg-white/[0.03]">
      <span className="text-muted-foreground [&_svg]:size-4">{icon}</span>
      <span className="text-xs text-muted-foreground">{label}</span>
      <span className="ml-auto truncate text-sm font-medium">{value || '—'}</span>
    </div>
  );
}

export function ProfileDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (open: boolean) => void }) {
  const { t } = useI18n();
  const me = useMe();
  const setPhoto = useSetStaffPhoto();
  const p = me.data;
  const [passwordOpen, setPasswordOpen] = useState(false);

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{t('profile.title')}</DialogTitle>
          <DialogDescription>{t('profile.subtitle')}</DialogDescription>
        </DialogHeader>
        {!p ? (
          <Skeleton className="h-64 rounded-2xl" />
        ) : (
          <div className="min-w-0 space-y-5">
            <div className="flex min-w-0 items-center gap-4">
              <div className="relative">
                <StaffAvatar name={p.fullName} photo={p.photo} portrait={p.portrait} size="xl" className="shadow-glass" />
                <label
                  htmlFor={INPUT_ID}
                  className="absolute -bottom-1.5 -right-1.5 flex h-9 w-9 cursor-pointer items-center justify-center rounded-full bg-brand-gradient text-white shadow-primary-glow ring-4 ring-background transition hover:brightness-110"
                  title={t('profile.photo.upload')}
                >
                  <Camera className="h-4 w-4" />
                  <span className="sr-only">{t('profile.photo.upload')}</span>
                </label>
              </div>
              <div className="min-w-0 flex-1">
                <p className="break-words font-display text-[1.05rem] font-semibold leading-snug">{p.fullName}</p>
                <Badge className="mt-2">{t(`enums.role.${p.role}`)}</Badge>
              </div>
            </div>
            <div className="space-y-2">
              <PhotoPicker
                inputId={INPUT_ID}
                hasPhoto={Boolean(p.photo)}
                busy={setPhoto.isPending}
                onPick={(photo) => setPhoto.mutate({ staffId: p.id, photo })}
                onRemove={() => setPhoto.mutate({ staffId: p.id, photo: null })}
              />
              <p className="text-xs text-muted-foreground">
                {t('profile.photo.hint')} {!p.photo && t('profile.photo.portraitNote')}
              </p>
            </div>
            <div className="grid min-w-0 gap-2">
              <Row icon={<Briefcase />} label={t('profile.fields.position')} value={p.position} />
              <Row icon={<Phone />} label={t('profile.fields.phone')} value={p.phone} />
              <Row icon={<AtSign />} label={t('profile.fields.email')} value={p.email} />
              {p.username && <Row icon={<KeyRound />} label={t('profile.fields.username')} value={p.username} />}
            </div>
            {isHttpMode && (
              <div className="rounded-2xl border p-3">
                <button
                  type="button"
                  className="flex w-full items-center justify-between text-sm font-medium"
                  aria-expanded={passwordOpen}
                  onClick={() => setPasswordOpen((v) => !v)}
                >
                  {t('auth.changePassword.voluntary')}
                  <ChevronDown className={`h-4 w-4 transition-transform ${passwordOpen ? 'rotate-180' : ''}`} />
                </button>
                {passwordOpen && (
                  <div className="mt-4">
                    <PasswordChangeForm onDone={() => setPasswordOpen(false)} />
                  </div>
                )}
              </div>
            )}
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
}
