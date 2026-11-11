'use client';

/**
 * Vaqtinchalik login-parol — FAQAT shu oynada, bir marta ko'rinadi (serverda
 * saqlanmaydi). Admin uni direktor / psixologga xavfsiz yo'l bilan beradi;
 * birinchi kirishda yangi parol o'rnatiladi.
 */

import { useState } from 'react';
import { toast } from 'sonner';
import { Check, Copy, KeyRound, ShieldAlert } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import type { AdminSchoolCredentials } from '@/types/api.types';
import { credentialsText, SCHOOL_PANEL_URL } from './school-form';

export interface ShownCredentials extends AdminSchoolCredentials {
  title: string;
  schoolName?: string;
}

export function CredentialsDialog({
  credentials,
  onClose,
}: {
  credentials: ShownCredentials | null;
  onClose: () => void;
}) {
  return (
    <Dialog open={credentials !== null} onOpenChange={(v) => !v && onClose()}>
      <DialogContent className="w-[calc(100vw-1.5rem)] max-w-lg">
        {credentials && <Body credentials={credentials} onClose={onClose} />}
      </DialogContent>
    </Dialog>
  );
}

function Body({ credentials: c, onClose }: { credentials: ShownCredentials; onClose: () => void }) {
  const [copied, setCopied] = useState(false);

  const copyAll = async () => {
    try {
      await navigator.clipboard.writeText(credentialsText(c));
      setCopied(true);
      toast.success('Nusxa olindi');
    } catch {
      toast.error("Nusxa olib bo'lmadi — qo'lda ko'chirib oling");
    }
  };

  const rows: Array<[string, string, boolean?]> = [
    ['Panel manzili', SCHOOL_PANEL_URL],
    ['Maktab kodi', c.schoolCode, true],
    ['Login', c.username, true],
    ['Vaqtinchalik parol', c.temporaryPassword, true],
  ];

  return (
    <>
      <DialogHeader>
        <DialogTitle className="flex items-center gap-2">
          <KeyRound className="h-5 w-5 text-primary" aria-hidden /> {c.title}
        </DialogTitle>
        <DialogDescription>{c.account.fullName} — panelga kirish ma&apos;lumotlari.</DialogDescription>
      </DialogHeader>

      <dl className="divide-y divide-border rounded-xl border border-border bg-muted/30">
        {rows.map(([label, value, mono]) => (
          <div key={label} className="flex flex-wrap items-center justify-between gap-2 px-4 py-3">
            <dt className="text-sm text-muted-foreground">{label}</dt>
            <dd className={mono ? 'select-all font-mono text-base font-semibold tracking-wide' : 'select-all text-sm'}>
              {value}
            </dd>
          </div>
        ))}
      </dl>

      <p className="flex gap-2 rounded-lg border border-warning/30 bg-warning/10 px-3 py-2 text-sm text-warning">
        <ShieldAlert className="mt-0.5 h-4 w-4 shrink-0" aria-hidden />
        Parol faqat hozir ko&apos;rinadi va hech qayerda saqlanmaydi. Uni direktorga shaxsan yoki xavfsiz messenjerda
        bering. Birinchi kirishda yangi parol o&apos;rnatiladi. Yo&apos;qolsa, «Parolni tiklash» orqali yangisini oling.
      </p>

      <div className="flex flex-wrap justify-end gap-2">
        <Button variant="outline" onClick={() => void copyAll()}>
          {copied ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
          Hammasini nusxalash
        </Button>
        <Button onClick={onClose}>Tayyor</Button>
      </div>
    </>
  );
}
