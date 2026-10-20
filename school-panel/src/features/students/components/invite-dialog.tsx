'use client';

import { Copy } from 'lucide-react';
import QRCode from 'react-qr-code';
import { toast } from 'sonner';

import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import type { Guardian } from '@/data/contracts';
import { useI18n } from '@/i18n';

/** Parvoz Parents taklif kodi + QR (ota-ona ilovada skanerlaydi). */
export function InviteDialog({ guardian, onOpenChange }: { guardian: Guardian | null; onOpenChange: (open: boolean) => void }) {
  const { t, formatDate } = useI18n();
  const code = guardian?.inviteCode ?? '';
  return (
    <Dialog open={Boolean(guardian)} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-sm">
        <DialogHeader>
          <DialogTitle>{t('students.detail.inviteTitle')}</DialogTitle>
          <DialogDescription>{t('students.detail.inviteText')}</DialogDescription>
        </DialogHeader>
        {guardian && (
          <div className="flex flex-col items-center gap-4 py-2">
            <div className="rounded-2xl border bg-white p-4">
              <QRCode value={`https://parvoz.uz/link?code=${code}`} size={176} />
            </div>
            <div className="text-center">
              <p className="text-xs uppercase tracking-wider text-muted-foreground">{t('students.detail.inviteCode')}</p>
              <p className="mt-1 font-display text-3xl font-semibold tracking-[0.3em]">{code}</p>
              {guardian.inviteExpiresAt && (
                <p className="mt-1 text-xs text-muted-foreground">
                  {t('students.detail.expires', { date: formatDate(guardian.inviteExpiresAt, 'd MMMM') })}
                </p>
              )}
            </div>
            <Button
              variant="outline"
              onClick={() => {
                void navigator.clipboard.writeText(code);
                toast.success(t('common.copied'));
              }}
            >
              <Copy />
              {t('common.copy')}
            </Button>
            <p className="text-center text-sm text-muted-foreground">
              {guardian.fullName} · {guardian.phone}
            </p>
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
}
