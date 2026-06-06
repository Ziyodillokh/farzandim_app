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
import { Textarea } from '@/components/ui/textarea';
import { Checkbox } from '@/components/ui/checkbox';
import { Switch } from '@/components/ui/switch';
import {
  Select,
  SelectTrigger,
  SelectValue,
  SelectContent,
  SelectItem,
} from '@/components/ui/select';
import { monetizationApi } from '@/lib/api/admin.api';
import { getApiErrorMessage } from '@/lib/api/client';
import {
  PLAN_FEATURE_GROUPS,
  TIER_FEATURE_PRESETS,
} from '@/lib/constants/plan-features';
import type { Plan } from '@/types/api.types';

interface PlanFormModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSuccess?: () => void;
}

function slugify(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/\s+/g, '-')
    .replace(/[^a-z0-9-]/g, '')
    .replace(/-+/g, '-');
}

const PERIOD_OPTIONS: { value: Plan['period']; label: string }[] = [
  { value: 'free', label: 'Bepul' },
  { value: 'monthly', label: 'Oylik' },
  { value: 'yearly', label: 'Yillik' },
];

const TIER_OPTIONS: { value: Plan['entitlementTier']; label: string }[] = [
  { value: 'free', label: 'Free' },
  { value: 'standard', label: 'Standard' },
  { value: 'premium', label: 'Premium' },
];

export function PlanFormModal({ open, onOpenChange, onSuccess }: PlanFormModalProps) {
  const [name, setName] = useState('');
  const [slug, setSlug] = useState('');
  const [slugEdited, setSlugEdited] = useState(false);
  const [priceUzs, setPriceUzs] = useState('');
  const [period, setPeriod] = useState<Plan['period']>('monthly');
  const [entitlementTier, setEntitlementTier] = useState<Plan['entitlementTier']>('standard');
  const [badge, setBadge] = useState('');
  const [description, setDescription] = useState('');
  const [features, setFeatures] = useState<Set<string>>(
    () => new Set(TIER_FEATURE_PRESETS.standard),
  );
  const [isActive, setIsActive] = useState(true);

  const reset = () => {
    setName('');
    setSlug('');
    setSlugEdited(false);
    setPriceUzs('');
    setPeriod('monthly');
    setEntitlementTier('standard');
    setBadge('');
    setDescription('');
    setFeatures(new Set(TIER_FEATURE_PRESETS.standard));
    setIsActive(true);
  };

  const handleNameChange = (value: string) => {
    setName(value);
    if (!slugEdited) setSlug(slugify(value));
  };

  // Daraja tanlanganda — shu darajaga mos funksiyalar to'plamini avtomatik
  // belgilaymiz (monetizatsiya modeli). Keyin admin alohida yoqib/o'chiradi.
  const handleTierChange = (value: Plan['entitlementTier']) => {
    setEntitlementTier(value);
    const preset = TIER_FEATURE_PRESETS[value];
    if (preset) setFeatures(new Set(preset));
  };

  const toggleFeature = (key: string) => {
    setFeatures((prev) => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      return next;
    });
  };

  const mutation = useMutation({
    mutationFn: () =>
      monetizationApi.plans.create({
        name: name.trim(),
        slug: slug.trim(),
        priceUzs: Number(priceUzs) || 0,
        period,
        entitlementTier,
        badge: badge.trim() || null,
        description: description.trim() || null,
        features: Array.from(features),
        isActive,
      }),
    onSuccess: () => {
      toast.success('Tarif yaratildi');
      onSuccess?.();
      reset();
      onOpenChange(false);
    },
    onError: (e) => toast.error(getApiErrorMessage(e)),
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) {
      toast.error('Nom kiritilishi shart');
      return;
    }
    if (!slug.trim()) {
      toast.error('Slug kiritilishi shart');
      return;
    }
    if (priceUzs === '' || Number.isNaN(Number(priceUzs))) {
      toast.error("To'g'ri narx kiriting");
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
      <DialogContent className="max-w-2xl">
        <DialogHeader>
          <DialogTitle>Yangi tarif</DialogTitle>
          <DialogDescription>Tarif rejasi ma&apos;lumotlarini kiriting.</DialogDescription>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-5">
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <Label htmlFor="plan-name">Nom *</Label>
              <Input
                id="plan-name"
                value={name}
                onChange={(e) => handleNameChange(e.target.value)}
                placeholder="Premium reja"
                required
              />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="plan-slug">Slug *</Label>
              <Input
                id="plan-slug"
                value={slug}
                onChange={(e) => {
                  setSlugEdited(true);
                  setSlug(slugify(e.target.value));
                }}
                placeholder="premium-reja"
                required
              />
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <Label htmlFor="plan-price">Narx (UZS) *</Label>
              <Input
                id="plan-price"
                type="number"
                min={0}
                value={priceUzs}
                onChange={(e) => setPriceUzs(e.target.value)}
                placeholder="0"
                required
              />
            </div>
            <div className="space-y-1.5">
              <Label>Davr</Label>
              <Select value={period} onValueChange={(v) => setPeriod(v as Plan['period'])}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {PERIOD_OPTIONS.map((opt) => (
                    <SelectItem key={opt.value} value={opt.value}>
                      {opt.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <Label>Daraja</Label>
              <Select
                value={entitlementTier}
                onValueChange={(v) => handleTierChange(v as Plan['entitlementTier'])}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {TIER_OPTIONS.map((opt) => (
                    <SelectItem key={opt.value} value={opt.value}>
                      {opt.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="plan-badge">Belgi (badge)</Label>
              <Input
                id="plan-badge"
                value={badge}
                onChange={(e) => setBadge(e.target.value)}
                placeholder="Mashhur"
              />
            </div>
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="plan-desc">Tavsif</Label>
            <Textarea
              id="plan-desc"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="Tarif haqida qisqacha..."
            />
          </div>

          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <Label>Imkoniyatlar</Label>
              <span className="text-xs text-muted-foreground">
                {features.size} ta tanlandi
              </span>
            </div>
            <div className="max-h-72 space-y-4 overflow-y-auto rounded-lg border border-border bg-muted/20 p-4">
              {PLAN_FEATURE_GROUPS.map((grp) => (
                <div key={grp.group} className="space-y-2">
                  <p className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                    {grp.group}
                  </p>
                  <div className="grid grid-cols-2 gap-2">
                    {grp.features.map((feat) => (
                      <label
                        key={feat.key}
                        htmlFor={`feat-${feat.key}`}
                        className="flex cursor-pointer items-center gap-2 text-sm"
                      >
                        <Checkbox
                          id={`feat-${feat.key}`}
                          checked={features.has(feat.key)}
                          onCheckedChange={() => toggleFeature(feat.key)}
                        />
                        <span className="text-foreground/90">{feat.label}</span>
                      </label>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="flex items-center justify-between rounded-lg border border-border p-3">
            <div className="space-y-0.5">
              <Label htmlFor="plan-active">Faol</Label>
              <p className="text-xs text-muted-foreground">Tarif foydalanuvchilarga ko&apos;rinadi</p>
            </div>
            <Switch id="plan-active" checked={isActive} onCheckedChange={setIsActive} />
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
