'use client';

import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Search, ChevronRight, CreditCard } from 'lucide-react';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { PageHeader } from '@/components/common/page-header';
import { PaymentStatusBadge } from '@/components/common/status-badge';
import { DataPagination } from '@/components/common/data-pagination';
import { EmptyState } from '@/components/common/empty-state';
import { monetizationApi } from '@/lib/api/admin.api';
import { cn, formatUzs, formatRelative } from '@/lib/utils';
import type { Payment } from '@/types/api.types';

const STATUS_FILTERS = [
  { value: '', label: 'Barcha statuslar' },
  { value: 'success', label: 'Muvaffaqiyatli' },
  { value: 'pending', label: 'Kutilmoqda' },
  { value: 'failed', label: 'Muvaffaqiyatsiz' },
  { value: 'refunded', label: 'Qaytarilgan' },
  { value: 'cancelled', label: 'Bekor qilingan' },
];
const METHOD_FILTERS = [
  { value: '', label: 'Barcha usullar' },
  { value: 'click', label: 'Click' },
  { value: 'payme', label: 'Payme' },
  { value: 'uzum_bank', label: 'Uzum Bank' },
  { value: 'visa', label: 'Visa' },
  { value: 'mastercard', label: 'Mastercard' },
];

const METHOD_LABELS: Record<string, string> = {
  click: 'Click',
  payme: 'Payme',
  uzum_bank: 'Uzum Bank',
  visa: 'Visa',
  mastercard: 'Mastercard',
};

export default function PaymentsPage() {
  const [status, setStatus] = useState('');
  const [method, setMethod] = useState('');
  const [page, setPage] = useState(1);
  const limit = 20;

  const params = { status, method, page, limit };
  const { data, isLoading, isFetching } = useQuery({
    queryKey: ['payments', params],
    queryFn: () => monetizationApi.payments.list(params),
    placeholderData: (prev) => prev,
  });

  return (
    <div className="container mx-auto max-w-screen-2xl px-6 py-8">
      <PageHeader eyebrow="Monetizatsiya" title="To'lovlar" count={data?.total} />

      {/* Filter bar */}
      <Card className="mb-4 p-4">
        <div className="flex flex-wrap items-center gap-3">
          <div className="min-w-[240px] flex-1">
            <Input icon={<Search />} placeholder="To'lovlar bo'yicha qidirish..." disabled />
          </div>
          <FilterSelect value={status} onChange={(v) => { setStatus(v); setPage(1); }} options={STATUS_FILTERS} />
          <FilterSelect value={method} onChange={(v) => { setMethod(v); setPage(1); }} options={METHOD_FILTERS} />
        </div>
      </Card>

      {/* Table */}
      <Card className="overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border bg-muted/30 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                <th className="px-4 py-3 text-left">Tranzaksiya ID</th>
                <th className="px-4 py-3 text-left">Tarif</th>
                <th className="px-4 py-3 text-left">Summa</th>
                <th className="px-4 py-3 text-left">Usul</th>
                <th className="px-4 py-3 text-left">Status</th>
                <th className="px-4 py-3 text-left">Sana</th>
              </tr>
            </thead>
            <tbody className={cn(isFetching && !isLoading && 'opacity-60 transition-opacity')}>
              {isLoading ? (
                Array.from({ length: 8 }).map((_, i) => <RowSkeleton key={i} />)
              ) : !data || data.items.length === 0 ? (
                <tr>
                  <td colSpan={6} className="p-0">
                    <EmptyState
                      icon={<CreditCard />}
                      title="To'lov topilmadi"
                      description="Bu filtrda hozircha to'lov yo'q. Filtrni o'zgartiring."
                    />
                  </td>
                </tr>
              ) : (
                data.items.map((p) => <PaymentRow key={p.id} payment={p} />)
              )}
            </tbody>
          </table>
        </div>

        {data && data.totalPages > 1 && (
          <DataPagination
            page={data.page}
            totalPages={data.totalPages}
            total={data.total}
            limit={limit}
            onPageChange={setPage}
          />
        )}
      </Card>
    </div>
  );
}

/* ─── Payment row ─── */

function PaymentRow({ payment }: { payment: Payment }) {
  return (
    <tr className="border-b border-border last:border-0 transition-colors hover:bg-accent/40">
      <td className="px-4 py-3">
        <span className="font-mono text-xs text-muted-foreground" title={payment.externalId ?? undefined}>
          {payment.externalId ? truncate(payment.externalId) : '—'}
        </span>
      </td>
      <td className="px-4 py-3 font-semibold">{payment.planName || '—'}</td>
      <td className="px-4 py-3 font-semibold tabular-nums">{formatUzs(payment.amount)}</td>
      <td className="px-4 py-3">
        <Badge variant="outline" size="sm">{METHOD_LABELS[payment.method] ?? payment.method}</Badge>
      </td>
      <td className="px-4 py-3">
        <PaymentStatusBadge status={payment.status} />
      </td>
      <td className="px-4 py-3 text-xs text-muted-foreground">{formatRelative(payment.paidAt ?? payment.createdAt)}</td>
    </tr>
  );
}

function truncate(value: string): string {
  return value.length > 18 ? `${value.slice(0, 8)}…${value.slice(-6)}` : value;
}

/* ─── FilterSelect (native, dependency-free) ─── */

function FilterSelect({
  value,
  onChange,
  options,
}: {
  value: string;
  onChange: (v: string) => void;
  options: Array<{ value: string; label: string }>;
}) {
  const current = options.find((o) => o.value === value) ?? options[0];
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="outline" className="min-w-[170px] justify-between">
          {current.label}
          <ChevronRight className="rotate-90" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent className="min-w-[180px]">
        {options.map((opt) => (
          <DropdownMenuItem
            key={opt.value}
            onClick={() => onChange(opt.value)}
            className={value === opt.value ? 'font-semibold text-primary' : ''}
          >
            {opt.label}
          </DropdownMenuItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}

/* ─── Row skeleton ─── */

function RowSkeleton() {
  return (
    <tr className="border-b border-border">
      <td className="px-4 py-3"><Skeleton className="h-3 w-32" /></td>
      <td className="px-4 py-3"><Skeleton className="h-3 w-20" /></td>
      <td className="px-4 py-3"><Skeleton className="h-3 w-24" /></td>
      <td className="px-4 py-3"><Skeleton className="h-5 w-16 rounded-full" /></td>
      <td className="px-4 py-3"><Skeleton className="h-5 w-20 rounded-full" /></td>
      <td className="px-4 py-3"><Skeleton className="h-3 w-20" /></td>
    </tr>
  );
}
