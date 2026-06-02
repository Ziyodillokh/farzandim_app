'use client';

import { useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { Ticket, Plus, Infinity as InfinityIcon } from 'lucide-react';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { PageHeader } from '@/components/common/page-header';
import { EmptyState } from '@/components/common/empty-state';
import { monetizationApi } from '@/lib/api/admin.api';
import { cn } from '@/lib/utils';
import { PromocodeFormModal } from '@/components/monetization/promocode-form-modal';
import type { Promocode } from '@/types/api.types';

const STATUS_META: Record<Promocode['status'], { label: string; variant: 'success' | 'secondary' | 'destructive'; dot: string }> = {
  active: { label: 'Faol', variant: 'success', dot: 'bg-success' },
  inactive: { label: 'Nofaol', variant: 'secondary', dot: 'bg-muted-foreground' },
  archived: { label: 'Arxivlangan', variant: 'destructive', dot: 'bg-destructive' },
};

function formatDate(iso: string | null): string {
  if (!iso) return '∞';
  const d = new Date(iso);
  if (isNaN(d.getTime())) return '—';
  return new Intl.DateTimeFormat('uz-UZ', { day: '2-digit', month: '2-digit', year: 'numeric' }).format(d);
}

export default function PromocodesPage() {
  const qc = useQueryClient();
  const [createOpen, setCreateOpen] = useState(false);
  const { data, isLoading } = useQuery({
    queryKey: ['promocodes'],
    queryFn: () => monetizationApi.promocodes.list(),
  });

  const invalidate = () => qc.invalidateQueries({ queryKey: ['promocodes'] });

  return (
    <div className="container mx-auto max-w-screen-2xl px-6 py-8">
      <PageHeader
        eyebrow="Monetizatsiya"
        title="Promokodlar"
        count={data?.length}
        actions={
          <Button onClick={() => setCreateOpen(true)}>
            <Plus className="h-4 w-4" /> Yangi promokod
          </Button>
        }
      />

      <PromocodeFormModal open={createOpen} onOpenChange={setCreateOpen} onSuccess={invalidate} />

      <Card className="overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border bg-muted/30 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                <th className="px-4 py-3 text-left">Kod</th>
                <th className="px-4 py-3 text-left">Chegirma</th>
                <th className="px-4 py-3 text-left">Foydalanish</th>
                <th className="px-4 py-3 text-left">Amal qilish muddati</th>
                <th className="px-4 py-3 text-left">Status</th>
              </tr>
            </thead>
            <tbody>
              {isLoading ? (
                Array.from({ length: 6 }).map((_, i) => <RowSkeleton key={i} />)
              ) : !data || data.length === 0 ? (
                <tr>
                  <td colSpan={5} className="p-0">
                    <EmptyState
                      icon={<Ticket />}
                      title="Promokod topilmadi"
                      description="Hozircha promokodlar yo'q. Yangi promokod qo'shing."
                    />
                  </td>
                </tr>
              ) : (
                data.map((promo) => <PromocodeRow key={promo.id} promo={promo} />)
              )}
            </tbody>
          </table>
        </div>
      </Card>
    </div>
  );
}

function PromocodeRow({ promo }: { promo: Promocode }) {
  const status = STATUS_META[promo.status] ?? STATUS_META.inactive;
  const unlimited = !promo.usageLimit || promo.usageLimit <= 0;
  const usagePct = unlimited ? 0 : Math.min(100, Math.round((promo.usedCount / promo.usageLimit) * 100));

  return (
    <tr className="border-b border-border last:border-0 transition-colors hover:bg-accent/40">
      <td className="px-4 py-3">
        <span className="rounded-md bg-muted px-2 py-1 font-mono text-xs font-semibold tracking-wide">
          {promo.code}
        </span>
      </td>
      <td className="px-4 py-3">
        <Badge variant="default" size="sm">−{promo.discountPct}%</Badge>
      </td>
      <td className="px-4 py-3">
        <div className="flex items-center gap-2">
          <span className="tabular-nums font-medium">
            {promo.usedCount}
            <span className="text-muted-foreground">
              {' / '}
              {unlimited ? <InfinityIcon className="inline h-3.5 w-3.5 align-text-bottom" /> : promo.usageLimit}
            </span>
          </span>
          {!unlimited && (
            <div className="h-1.5 w-16 overflow-hidden rounded-full bg-muted">
              <div className="h-full rounded-full bg-primary" style={{ width: `${usagePct}%` }} />
            </div>
          )}
        </div>
      </td>
      <td className="px-4 py-3 text-muted-foreground">{formatDate(promo.expiresAt)}</td>
      <td className="px-4 py-3">
        <Badge variant={status.variant} size="sm">
          <span className={cn('h-1.5 w-1.5 rounded-full', status.dot)} />
          {status.label}
        </Badge>
      </td>
    </tr>
  );
}

function RowSkeleton() {
  return (
    <tr className="border-b border-border">
      <td className="px-4 py-3"><Skeleton className="h-6 w-24 rounded-md" /></td>
      <td className="px-4 py-3"><Skeleton className="h-5 w-14 rounded-full" /></td>
      <td className="px-4 py-3"><Skeleton className="h-3 w-24" /></td>
      <td className="px-4 py-3"><Skeleton className="h-3 w-20" /></td>
      <td className="px-4 py-3"><Skeleton className="h-5 w-16 rounded-full" /></td>
    </tr>
  );
}
