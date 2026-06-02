'use client';

import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { toast } from 'sonner';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Select,
  SelectTrigger,
  SelectValue,
  SelectContent,
  SelectItem,
} from '@/components/ui/select';
import { monetizationApi } from '@/lib/api/admin.api';
import { getApiErrorMessage } from '@/lib/api/client';
import type { Promocode } from '@/types/api.types';

interface PromocodeFormModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSuccess?: () => void;
}

const STATUS_OPTIONS: { value: Promocode['status']; label: string }[] = [
  { value: 'active', label: 'Faol' },
  { value: 'inactive', label: 'Nofaol' },
  { value: 'archived', label: 'Arxivlangan' },
];

/** ISO sana (yyyy-mm-dd) — bugundan N kun keyin. */
function defaultExpiry(daysAhead: number): string {
  const d = new Date();
  d.setDate(d.getDate() + daysAhead);
  return d.toISOString().slice(0, 10);
}

export function PromocodeFormModal({ open, onOpenChange, onSuccess }: PromocodeFormModalProps) {
  const [code, setCode] = useState('');
  const [discountPct, setDiscountPct] = useState('');
  const [usageLimit, setUsageLimit] = useState('1000');
  const [expiresAt, setExpiresAt] = useState<string>(() => defaultExpiry(30));
  const [status, setStatus] = useState<Promocode['status']>('active');

  const reset = () => {
    setCode('');
    setDiscountPct('');
    setUsageLimit('1000');
    setExpiresAt(defaultExpiry(30));
    setStatus('active');
  };

  const mutation = useMutation({
    mutationFn: () =>
      monetizationApi.promocodes.create({
        code: code.trim().toUpperCase(),
        discountPct: Number(discountPct) || 0,
        usageLimit: Number(usageLimit) || 0,
        expiresAt: expiresAt ? new Date(expiresAt).toISOString() : null,
        status,
      }),
    onSuccess: () => {
      toast.success('Promokod yaratildi');
      onSuccess?.();
      reset();
      onOpenChange(false);
    },
    onError: (e) => toast.error(getApiErrorMessage(e)),
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!code.trim()) {
      toast.error('Kod kiritilishi shart');
      return;
    }
    const pct = Number(discountPct);
    if (discountPct === '' || Number.isNaN(pct) || pct < 0 || pct > 100) {
      toast.error('Chegirma 0 dan 100 gacha bo‘lishi kerak');
      return;
    }
    mutation.mutate();
  };

  return (
    <Dialog
      open={open}
      onOpenChange={(o) => {
        if (!o && !mutation.isPending) reset();
        onOpenChange(o);
      }}
    >
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Yangi promokod</DialogTitle>
          <DialogDescription>Promokod ma&apos;lumotlarini kiriting.</DialogDescription>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-5">
          <div className="space-y-1.5">
            <Label htmlFor="promo-code">Kod *</Label>
            <Input
              id="promo-code"
              value={code}
              onChange={(e) => setCode(e.target.value.toUpperCase())}
              placeholder="WELCOME10"
              className="font-mono uppercase"
              required
            />
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <Label htmlFor="promo-discount">Chegirma (%) *</Label>
              <Input
                id="promo-discount"
                type="number"
                min={0}
                max={100}
                value={discountPct}
                onChange={(e) => setDiscountPct(e.target.value)}
                placeholder="10"
                required
              />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="promo-limit">Foydalanish limiti</Label>
              <Input
                id="promo-limit"
                type="number"
                min={0}
                value={usageLimit}
                onChange={(e) => setUsageLimit(e.target.value)}
                placeholder="1000"
              />
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <Label htmlFor="promo-expires">Amal qilish muddati</Label>
              <Input
                id="promo-expires"
                type="date"
                value={expiresAt}
                onChange={(e) => setExpiresAt(e.target.value)}
              />
            </div>
            <div className="space-y-1.5">
              <Label>Status</Label>
              <Select value={status} onValueChange={(v) => setStatus(v as Promocode['status'])}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {STATUS_OPTIONS.map((opt) => (
                    <SelectItem key={opt.value} value={opt.value}>
                      {opt.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>

          <DialogFooter className="gap-2">
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
              disabled={mutation.isPending}
            >
              Bekor qilish
            </Button>
            <Button type="submit" loading={mutation.isPending}>
              Yaratish
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
