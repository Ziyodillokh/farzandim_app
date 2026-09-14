'use client';

import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { AlertTriangle } from 'lucide-react';
import { toast } from 'sonner';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogFooter,
  DialogTitle,
  DialogDescription,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { usersApi } from '@/lib/api/admin.api';
import { getApiErrorMessage } from '@/lib/api/client';
import type { AdminUserListItem } from '@/types/api.types';

const MAX = 500;

/** Ogohlantirish — foydalanuvchiga push (bola uchun + in-app inbox). */
export function WarnUserDialog({
  user,
  open,
  onOpenChange,
}: {
  user: AdminUserListItem;
  open: boolean;
  onOpenChange: (v: boolean) => void;
}) {
  const [message, setMessage] = useState('');

  const warn = useMutation({
    mutationFn: () => usersApi.warn(user.id, message.trim()),
    onSuccess: (r) => {
      toast.success(
        r.delivered > 0
          ? 'Ogohlantirish yuborildi'
          : "Ogohlantirish saqlandi (qurilmada push tokeni yo'q)",
      );
      setMessage('');
      onOpenChange(false);
    },
    onError: (err) => toast.error(getApiErrorMessage(err)),
  });

  const canSend = message.trim().length > 0 && message.length <= MAX && !warn.isPending;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <AlertTriangle className="h-5 w-5 text-warning" /> Ogohlantirish yuborish
          </DialogTitle>
          <DialogDescription>
            <span className="font-semibold text-foreground">{user.name}</span> ilovasiga push
            bildirishnoma sifatida boradi. Matn qisqa va aniq bo&apos;lsin.
          </DialogDescription>
        </DialogHeader>

        <div className="flex flex-col gap-2">
          <Label htmlFor="warn-message">Xabar matni</Label>
          <Textarea
            id="warn-message"
            rows={4}
            maxLength={MAX}
            placeholder="Masalan: Platforma qoidalarini buzganingiz uchun ogohlantirish. Takrorlansa akkaunt bloklanadi."
            value={message}
            onChange={(e) => setMessage(e.target.value)}
          />
          <p className="text-right text-2xs text-muted-foreground tabular-nums">
            {message.length}/{MAX}
          </p>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)} disabled={warn.isPending}>
            Bekor qilish
          </Button>
          <Button onClick={() => warn.mutate()} disabled={!canSend} loading={warn.isPending}>
            Yuborish
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
