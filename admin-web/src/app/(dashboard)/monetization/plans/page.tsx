'use client';

import { useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { Check, Plus, Sparkles, CircleDollarSign } from 'lucide-react';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { PageHeader } from '@/components/common/page-header';
import { EmptyState } from '@/components/common/empty-state';
import { monetizationApi } from '@/lib/api/admin.api';
import { cn, formatUzs } from '@/lib/utils';
import { PlanFormModal } from '@/components/monetization/plan-form-modal';
import type { Plan } from '@/types/api.types';

const PERIOD_LABEL: Record<Plan['period'], string> = {
  free: 'Bepul',
  monthly: 'oyiga',
  yearly: 'yiliga',
};

const TIER_META: Record<Plan['entitlementTier'], { label: string; variant: 'secondary' | 'info' | 'warning' | 'success' }> = {
  free: { label: 'Free', variant: 'secondary' },
  basic: { label: 'Basic', variant: 'info' },
  standard: { label: 'Standard', variant: 'warning' },
  premium: { label: 'Premium', variant: 'success' },
};

export default function PlansPage() {
  const qc = useQueryClient();
  const [createOpen, setCreateOpen] = useState(false);
  const { data, isLoading } = useQuery({
    queryKey: ['plans'],
    queryFn: () => monetizationApi.plans.list(),
  });

  const invalidate = () => qc.invalidateQueries({ queryKey: ['plans'] });

  const plans = (data ?? []).slice().sort((a, b) => a.sortOrder - b.sortOrder);

  return (
    <div className="container mx-auto max-w-screen-2xl px-6 py-8">
      <PageHeader
        eyebrow="Monetizatsiya"
        title="Tariflar"
        count={data?.length}
        actions={
          <Button onClick={() => setCreateOpen(true)}>
            <Plus className="h-4 w-4" /> Yangi tarif
          </Button>
        }
      />

      <PlanFormModal open={createOpen} onOpenChange={setCreateOpen} onSuccess={invalidate} />

      {isLoading ? (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          {Array.from({ length: 4 }).map((_, i) => (
            <Card key={i} className="p-6">
              <Skeleton className="h-5 w-24" />
              <Skeleton className="mt-4 h-9 w-32" />
              <div className="mt-6 space-y-2.5">
                {Array.from({ length: 4 }).map((__, j) => (
                  <Skeleton key={j} className="h-3.5 w-full" />
                ))}
              </div>
            </Card>
          ))}
        </div>
      ) : plans.length === 0 ? (
        <Card>
          <EmptyState
            icon={<CircleDollarSign />}
            title="Tarif topilmadi"
            description="Hozircha tariflar yo'q. Yangi tarif qo'shing."
            action={
              <Button onClick={() => setCreateOpen(true)}>
                <Plus className="h-4 w-4" /> Yangi tarif
              </Button>
            }
          />
        </Card>
      ) : (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          {plans.map((plan) => (
            <PlanCard key={plan.id} plan={plan} />
          ))}
        </div>
      )}
    </div>
  );
}

function PlanCard({ plan }: { plan: Plan }) {
  const tier = TIER_META[plan.entitlementTier];
  const highlighted = plan.entitlementTier === 'premium';

  return (
    <Card
      className={cn(
        'card-glow relative flex flex-col p-6',
        highlighted && 'border-primary/50 ring-1 ring-primary/20',
        !plan.isActive && 'opacity-70',
      )}
    >
      {plan.badge && (
        <span className="absolute -top-2.5 right-5 flex items-center gap-1 rounded-full bg-primary px-2.5 py-0.5 text-2xs font-semibold text-primary-foreground shadow-soft">
          <Sparkles className="h-3 w-3" /> {plan.badge}
        </span>
      )}

      <div className="flex items-start justify-between gap-2">
        <div>
          <h3 className="text-base font-bold">{plan.name}</h3>
          <Badge variant={tier.variant} size="sm" className="mt-1.5">{tier.label}</Badge>
        </div>
        <Badge variant={plan.isActive ? 'success' : 'secondary'} size="sm">
          <span className={cn('h-1.5 w-1.5 rounded-full', plan.isActive ? 'bg-success' : 'bg-muted-foreground')} />
          {plan.isActive ? 'Faol' : 'Nofaol'}
        </Badge>
      </div>

      <div className="mt-5 flex items-end gap-1.5">
        <span className="text-3xl font-bold tracking-tight">{formatUzs(plan.priceUzs)}</span>
        {plan.period !== 'free' && (
          <span className="pb-1 text-sm text-muted-foreground">/ {PERIOD_LABEL[plan.period]}</span>
        )}
      </div>

      {plan.description && (
        <p className="mt-3 text-sm text-muted-foreground">{plan.description}</p>
      )}

      <ul className="mt-5 flex-1 space-y-2.5">
        {plan.features.length === 0 ? (
          <li className="text-sm text-muted-foreground">Imkoniyatlar ko&apos;rsatilmagan</li>
        ) : (
          plan.features.map((feature, i) => (
            <li key={i} className="flex items-start gap-2 text-sm">
              <span className="mt-0.5 flex h-4 w-4 shrink-0 items-center justify-center rounded-full bg-primary/10 text-primary">
                <Check className="h-2.5 w-2.5" />
              </span>
              <span className="text-foreground/90">{feature}</span>
            </li>
          ))
        )}
      </ul>

      <Button variant="outline" className="mt-6 w-full">Tahrirlash</Button>
    </Card>
  );
}
