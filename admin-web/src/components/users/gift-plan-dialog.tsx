'use client';

import { useEffect, useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { format } from 'date-fns';
import { Gift, Sparkles } from 'lucide-react';
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
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Badge } from '@/components/ui/badge';
import {
  Select,
  SelectTrigger,
  SelectValue,
  SelectContent,
  SelectItem,
} from '@/components/ui/select';
import { monetizationApi, usersApi } from '@/lib/api/admin.api';
import { getApiErrorMessage } from '@/lib/api/client';
import { cn, formatUzs } from '@/lib/utils';
import type { AdminUserListItem } from '@/types/api.types';

const DAY_PRESETS = [3, 7, 14, 30];
const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Sovg'a / demo — ota-onaga tanlangan tarifni N kun BEPUL berish.
 * Faol obuna bo'lsa muddat uzayadi (backend qoidasi: tarif pastga tushmaydi).
 */
export function GiftPlanDialog({
  user,
  open,
  onOpenChange,
}: {
  user: AdminUserListItem;
  open: boolean;
  onOpenChange: (v: boolean) => void;
}) {
  const qc = useQueryClient();
  const [planId, setPlanId] = useState('');
  const [days, setDays] = useState(7);
  const [note, setNote] = useState('');

  // Faol pullik tariflar (free chiqarilmaydi — sovg'a qilib bo'lmaydi).
  const { data: plans, isLoading: plansLoading } = useQuery({
    queryKey: ['plans'],
    queryFn: () => monetizationApi.plans.list(),
    enabled: open,
    staleTime: 60_000,
  });
  const giftable = useMemo(
    () => (plans ?? []).filter((p) => p.isActive && p.entitlementTier !== 'free'),
    [plans],
  );

  // Hozirgi obuna — "uzayadi" yoki "yangi" ekanini ko'rsatish uchun.
  const { data: detail } = useQuery({
    queryKey: ['user-detail', user.id],
    queryFn: () => usersApi.detail(user.id),
    enabled: open,
  });
  const current = detail?.subscription ?? null;
  const currentActive = current?.expiresAt
    ? new Date(current.expiresAt).getTime() > Date.now()
    : Boolean(current && current.expiresAt === null);

  // Birinchi tarif avtomatik tanlansin (Standart bo'lsa — u).
  useEffect(() => {
    if (!planId && giftable.length > 0) {
      const std = giftable.find((p) => p.entitlementTier === 'standard');
      setPlanId((std ?? giftable[0]).id);
    }
  }, [giftable, planId]);

  const selected = giftable.find((p) => p.id === planId);
  const validDays = Number.isInteger(days) && days >= 1 && days <= 365;
  const endsAt = useMemo(() => {
    const base =
      currentActive && current?.expiresAt ? new Date(current.expiresAt).getTime() : Date.now();
    return new Date(base + (validDays ? days : 0) * DAY_MS);
  }, [currentActive, current?.expiresAt, days, validDays]);

  const grant = useMutation({
    mutationFn: () =>
      usersApi.grantSubscription(user.id, {
        planId,
        days,
        note: note.trim() || undefined,
      }),
    onSuccess: async (r) => {
      toast.success(
        r.extended
          ? `${r.planName} muddati ${days} kunga uzaytirildi`
          : `${r.planName} ${days} kunga sovg'a qilindi`,
      );
      onOpenChange(false);
      setNote('');
      await Promise.all([
        qc.invalidateQueries({ queryKey: ['users'] }),
        qc.invalidateQueries({ queryKey: ['user-detail', user.id] }),
      ]);
    },
    onError: (err) => toast.error(getApiErrorMessage(err)),
  });

  const canSubmit = Boolean(planId) && validDays && !grant.isPending;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <Gift className="h-5 w-5 text-primary" /> Tarif sovg&apos;a qilish
          </DialogTitle>
          <DialogDescription>
            <span className="font-semibold text-foreground">{user.name}</span> uchun tanlangan
            tarif belgilangan kun davomida <b className="text-foreground">bepul</b> faol bo&apos;ladi.
            Muddat tugagach avtomatik Free&apos;ga qaytadi.
          </DialogDescription>
        </DialogHeader>

        <div className="flex flex-col gap-4">
          {/* Hozirgi holat */}
          <div className="flex items-center justify-between rounded-xl border border-border bg-muted/30 px-3 py-2 text-sm">
            <span className="text-muted-foreground">Hozirgi obuna</span>
            {current && currentActive ? (
              <span className="flex items-center gap-1.5 font-medium">
                {current.planName}
                {current.isTrial && (
                  <Badge variant="warning" size="sm">Demo</Badge>
                )}
                {current.expiresAt && (
                  <span className="text-xs text-muted-foreground">
                    · {format(new Date(current.expiresAt), 'dd.MM.yyyy')} gacha
                  </span>
                )}
              </span>
            ) : (
              <span className="font-medium">Free</span>
            )}
          </div>

          {/* Tarif */}
          <div className="flex flex-col gap-2">
            <Label>Tarif</Label>
            <Select value={planId} onValueChange={setPlanId} disabled={plansLoading}>
              <SelectTrigger>
                <SelectValue placeholder={plansLoading ? 'Yuklanmoqda...' : 'Tarifni tanlang'} />
              </SelectTrigger>
              <SelectContent>
                {giftable.map((p) => (
                  <SelectItem key={p.id} value={p.id}>
                    <span className="flex items-center gap-2">
                      <Sparkles className="h-3.5 w-3.5 text-primary" />
                      {p.name}
                      <span className="text-xs text-muted-foreground">
                        · {formatUzs(p.priceUzs)} / {p.period === 'yearly' ? 'yil' : 'oy'}
                      </span>
                    </span>
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            {!plansLoading && giftable.length === 0 && (
              <p className="text-xs text-destructive">Faol pullik tarif topilmadi</p>
            )}
          </div>

          {/* Kunlar */}
          <div className="flex flex-col gap-2">
            <Label htmlFor="gift-days">Necha kun</Label>
            <div className="flex flex-wrap items-center gap-2">
              {DAY_PRESETS.map((d) => (
                <button
                  key={d}
                  type="button"
                  onClick={() => setDays(d)}
                  className={cn(
                    'rounded-full border px-3 py-1 text-sm font-medium transition-colors',
                    days === d
                      ? 'border-primary bg-primary/10 text-primary'
                      : 'border-border text-muted-foreground hover:bg-accent hover:text-foreground',
                  )}
                >
                  {d} kun
                </button>
              ))}
              <Input
                id="gift-days"
                type="number"
                min={1}
                max={365}
                value={days}
                onChange={(e) => setDays(Number(e.target.value))}
                className="h-8 w-24"
              />
            </div>
            {!validDays && <p className="text-xs text-destructive">1 dan 365 gacha kun kiriting</p>}
          </div>

          {/* Izoh */}
          <div className="flex flex-col gap-2">
            <Label htmlFor="gift-note">
              Izoh <span className="font-normal text-muted-foreground">(ixtiyoriy, audit log uchun)</span>
            </Label>
            <Input
              id="gift-note"
              maxLength={300}
              placeholder="Masalan: konkurs g'olibi, shikoyat kompensatsiyasi..."
              value={note}
              onChange={(e) => setNote(e.target.value)}
            />
          </div>

          {/* Natija */}
          {selected && validDays && (
            <p className="rounded-xl bg-primary/5 px-3 py-2 text-sm">
              <b>{selected.name}</b>{' '}
              {currentActive ? 'muddati uzayadi' : 'faollashadi'} →{' '}
              <b>{format(endsAt, 'dd.MM.yyyy')}</b> gacha
              {currentActive && ' (hozirgi obuna tugagan sanadan boshlab)'}
            </p>
          )}
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)} disabled={grant.isPending}>
            Bekor qilish
          </Button>
          <Button onClick={() => grant.mutate()} disabled={!canSubmit} loading={grant.isPending}>
            <Gift className="h-4 w-4" /> Sovg&apos;a qilish
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
