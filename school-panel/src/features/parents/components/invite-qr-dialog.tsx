'use client';

import { Copy, Link2, MessageSquareText } from 'lucide-react';
import QRCode from 'react-qr-code';

import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import type { Guardian } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { useCopy } from '../hooks';

const LINK_BASE = 'https://parvoz.uz/link?code=';
const QR_SIZE = 184;

export function inviteLink(code: string): string {
  return `${LINK_BASE}${encodeURIComponent(code)}`;
}

/** Parvoz Parents taklif kodi + QR (ota-ona ilovada skanerlaydi). */
export function InviteQrDialog({ guardian, onOpenChange }: { guardian: Guardian | null; onOpenChange: (open: boolean) => void }) {
  const { t, formatDate } = useI18n();
  const copy = useCopy();
  const code = guardian?.inviteCode ?? '';
  const steps = [t('parents.inviteDialog.step1'), t('parents.inviteDialog.step2'), t('parents.inviteDialog.step3')];

  return (
    <Dialog open={Boolean(guardian && code)} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[92vh] overflow-y-auto sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{t('parents.inviteDialog.title')}</DialogTitle>
          <DialogDescription>{t('parents.inviteDialog.text')}</DialogDescription>
        </DialogHeader>
        {guardian && code && (
          <div className="flex flex-col items-center gap-4 animate-fade-in">
            <p className="text-center text-sm font-medium">
              {guardian.fullName} <span className="text-muted-foreground">· {t(`enums.relation.${guardian.relation}`)}</span>
            </p>
            <div className="rounded-2xl border bg-white p-4 shadow-soft">
              <QRCode value={inviteLink(code)} size={QR_SIZE} aria-label={code} />
            </div>
            <div className="text-center">
              <p className="text-2xs font-semibold uppercase tracking-wider text-muted-foreground">{t('parents.inviteDialog.code')}</p>
              <p className="mt-1 select-all font-display text-3xl font-semibold tracking-[0.3em]">{code}</p>
              {guardian.inviteExpiresAt && (
                <p className="mt-1 text-xs text-muted-foreground">
                  {t('parents.inviteDialog.expires', { date: formatDate(guardian.inviteExpiresAt, 'd MMMM, HH:mm') })}
                </p>
              )}
            </div>
            <div className="flex flex-wrap justify-center gap-2">
              <Button variant="outline" size="sm" onClick={() => void copy(code)}>
                <Copy />
                {t('parents.inviteDialog.copyCode')}
              </Button>
              <Button variant="outline" size="sm" onClick={() => void copy(inviteLink(code))}>
                <Link2 />
                {t('parents.inviteDialog.copyLink')}
              </Button>
            </div>
            <p className="flex items-center gap-2 rounded-lg bg-success/10 px-3 py-2 text-xs font-medium text-success">
              <MessageSquareText className="h-4 w-4 shrink-0" />
              {t('parents.inviteDialog.sms', { phone: guardian.phone })}
            </p>
            <div className="w-full rounded-xl border bg-muted/40 p-4">
              <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">{t('parents.inviteDialog.stepsTitle')}</p>
              <ol className="space-y-2 text-sm">
                {steps.map((step, i) => (
                  <li key={step} className="flex items-start gap-2.5">
                    <span className="flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-primary text-2xs font-semibold text-primary-foreground">
                      {i + 1}
                    </span>
                    {step}
                  </li>
                ))}
              </ol>
            </div>
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
}
