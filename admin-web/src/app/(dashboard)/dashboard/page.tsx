'use client';

import { useQuery } from '@tanstack/react-query';
import { TrendingDown, TrendingUp, Users, Video, Headphones, Trophy, CreditCard } from 'lucide-react';
import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
  Legend,
} from 'recharts';
import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { dashboardApi } from '@/lib/api/admin.api';
import { cn, formatCompact } from '@/lib/utils';

const KPI_CONFIG = [
  { key: 'todayLogins', title: 'Bugungi kirishlar', icon: Users, color: 'text-primary', bg: 'bg-primary/10' },
  { key: 'videosUploaded', title: 'Yuklangan videolar', icon: Video, color: 'text-info', bg: 'bg-info/10' },
  { key: 'audiobooks', title: 'Audiokitoblar', icon: Headphones, color: 'text-warning', bg: 'bg-warning/10' },
  { key: 'activeContests', title: 'Faol konkurslar', icon: Trophy, color: 'text-destructive', bg: 'bg-destructive/10' },
  { key: 'paidPlanBuyers', title: 'Pullik obunalar', icon: CreditCard, color: 'text-success', bg: 'bg-success/10' },
] as const;

export default function DashboardPage() {
  const { data, isLoading } = useQuery({
    queryKey: ['dashboard'],
    queryFn: () => dashboardApi.stats(),
  });

  return (
    <div className="container mx-auto max-w-screen-2xl px-6 py-8">
      {/* Greeting */}
      <div className="mb-8 flex flex-wrap items-end justify-between gap-4">
        <div>
          <h2 className="text-2xl font-bold tracking-tight">Salom! 👋</h2>
          <p className="mt-1 text-sm text-muted-foreground">
            Parvoz platformasi statistikasi va asosiy ko'rsatkichlar
          </p>
        </div>
      </div>

      {/* KPI Grid — responsive */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5">
        {KPI_CONFIG.map((kpi) => {
          const value = data?.summary[kpi.key] ?? 0;
          const trend = data?.trends[kpi.key] ?? 0;
          const Icon = kpi.icon;
          return (
            <Card key={kpi.key} className="card-glow p-5">
              {isLoading ? (
                <KpiSkeleton />
              ) : (
                <>
                  <div className="mb-3 flex items-center justify-between">
                    <div className={cn('flex h-10 w-10 items-center justify-center rounded-lg', kpi.bg)}>
                      <Icon className={cn('h-5 w-5', kpi.color)} />
                    </div>
                    <TrendChip value={trend} />
                  </div>
                  <p className="text-xs font-medium text-muted-foreground">{kpi.title}</p>
                  <p className="mt-1 text-2xl font-bold tabular-nums">{formatCompact(value)}</p>
                </>
              )}
            </Card>
          );
        })}
      </div>

      {/* Charts */}
      <div className="mt-6 grid grid-cols-1 gap-4 lg:grid-cols-2">
        <ChartCard
          title="Foydalanuvchilar o'sishi"
          subtitle="Oxirgi 7 kun"
          chart={data?.charts.usersGrowth}
          loading={isLoading}
          accent="primary"
        />
        <ChartCard
          title="Faol foydalanuvchilar"
          subtitle="Oxirgi 7 kun"
          chart={data?.charts.activeUsers}
          loading={isLoading}
          accent="info"
        />
      </div>
    </div>
  );
}

/* ─── KPI helpers ─── */

function TrendChip({ value }: { value: number }) {
  const up = value >= 0;
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs font-semibold',
        up ? 'bg-success/10 text-success' : 'bg-destructive/10 text-destructive',
      )}
    >
      {up ? <TrendingUp className="h-3 w-3" /> : <TrendingDown className="h-3 w-3" />}
      {up ? '+' : ''}
      {value.toFixed(1)}%
    </span>
  );
}

function KpiSkeleton() {
  return (
    <>
      <div className="mb-3 flex items-center justify-between">
        <Skeleton className="h-10 w-10 rounded-lg" />
        <Skeleton className="h-5 w-14" />
      </div>
      <Skeleton className="h-3 w-24" />
      <Skeleton className="mt-2 h-7 w-20" />
    </>
  );
}

/* ─── Chart Card ─── */

interface ChartCardProps {
  title: string;
  subtitle: string;
  chart?: import('@/types/api.types').DashboardChart;
  loading: boolean;
  accent: 'primary' | 'info';
}

function ChartCard({ title, subtitle, chart, loading, accent }: ChartCardProps) {
  const color = accent === 'primary' ? 'hsl(78 90% 47%)' : 'hsl(217 91% 60%)';
  const labels = chart?.labels ?? [];
  const series = chart?.series ?? [];

  // Recharts uchun data formati: [{ name: 'label', ser1: val, ser2: val }, ...]
  const data = labels.map((label, i) => {
    const row: Record<string, string | number> = { name: label };
    series.forEach((s) => {
      row[s.name] = s.data[i] ?? 0;
    });
    return row;
  });

  return (
    <Card className="p-5">
      <div className="mb-4 flex items-start justify-between">
        <div>
          <p className="text-sm font-semibold">{title}</p>
          <p className="mt-0.5 text-xs text-muted-foreground">{subtitle}</p>
        </div>
        {!loading && chart && (
          <div className="flex flex-col items-end">
            <p className="text-2xl font-bold tabular-nums">{formatCompact(chart.headlineTotal)}</p>
            <TrendChip value={chart.changePercent} />
          </div>
        )}
      </div>
      {loading ? (
        <Skeleton className="h-56 w-full rounded-lg" />
      ) : (
        <div className="h-56 w-full">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={data} margin={{ top: 5, right: 5, left: -20, bottom: 0 }}>
              <defs>
                <linearGradient id={`grad-${accent}`} x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor={color} stopOpacity={0.35} />
                  <stop offset="95%" stopColor={color} stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" vertical={false} />
              <XAxis
                dataKey="name"
                stroke="hsl(var(--muted-foreground))"
                fontSize={11}
                tickLine={false}
                axisLine={false}
              />
              <YAxis
                stroke="hsl(var(--muted-foreground))"
                fontSize={11}
                tickLine={false}
                axisLine={false}
                width={32}
              />
              <Tooltip
                contentStyle={{
                  background: 'hsl(var(--popover))',
                  border: '1px solid hsl(var(--border))',
                  borderRadius: '0.5rem',
                  fontSize: 12,
                }}
              />
              {series.length > 1 && <Legend iconType="circle" wrapperStyle={{ fontSize: 12 }} />}
              {series.map((s, idx) => (
                <Area
                  key={s.name}
                  type="monotone"
                  dataKey={s.name}
                  stroke={idx === 0 ? color : 'hsl(var(--muted-foreground))'}
                  strokeWidth={2}
                  fill={`url(#grad-${accent})`}
                />
              ))}
            </AreaChart>
          </ResponsiveContainer>
        </div>
      )}
    </Card>
  );
}
