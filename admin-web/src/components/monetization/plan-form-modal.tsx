'use client';

import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { X } from 'lucide-react';
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
import { Badge } from '@/components/ui/badge';
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
  const [features, setFeatures] = useState<string[]>([]);
  const [featureInput, setFeatureInput] = useState('');
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
    setFeatures([]);
    setFeatureInput('');
    setIsActive(true);
  };

  const handleNameChange = (value: string) => {
    setName(value);
    if (!slugEdited) setSlug(slugify(value));
  };

  const addFeature = () => {
    const trimmed = featureInput.trim();
    if (!trimmed) return;
    setFeatures((prev) => (prev.includes(trimmed) ? prev : [...prev, trimmed]));
    setFeatureInput('');
  };

  const removeFeature = (feature: string) => {
    setFeatures((prev) => prev.filter((f) => f !== feature));
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
        features,
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
                onValueChange={(v) => setEntitlementTier(v as Plan['entitlementTier'])}
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
            <Label htmlFor="plan-feature">Imkoniyatlar</Label>
            <div className="flex gap-2">
              <Input
                id="plan-feature"
                value={featureInput}
                onChange={(e) => setFeatureInput(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') {
                    e.preventDefault();
                    addFeature();
                  }
                }}
                placeholder="Masalan: Cheksiz video"
              />
              <Button type="button" variant="outline" className="shrink-0" onClick={addFeature}>
                Qo&apos;shish
              </Button>
            </div>
            {features.length > 0 && (
              <div className="flex flex-wrap gap-2 pt-1">
                {features.map((feature) => (
                  <Badge key={feature} variant="secondary" className="gap-1.5 pr-1.5">
                    {feature}
                    <button
                      type="button"
                      onClick={() => removeFeature(feature)}
                      className="rounded-full p-0.5 hover:bg-foreground/10"
                      aria-label="O'chirish"
                    >
                      <X className="h-3 w-3" />
                    </button>
                  </Badge>
                ))}
              </div>
            )}
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
