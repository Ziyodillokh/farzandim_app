'use client';

import { useQuery } from '@tanstack/react-query';
import {
  BarChart3, TrendingUp, Users, Video, Headphones, BookOpen,
} from 'lucide-react';
import {
  Area, AreaChart, Bar, BarChart, CartesianGrid, ResponsiveContainer,
  Tooltip, XAxis, YAxis, Cell,
} from 'recharts';
import { Card, CardHeader, CardTitle } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { PageHeader } from '@/components/common/page-header';
import { analyticsApi } from '@/lib/api/admin.api';
import { cn, formatCompact } from '@/lib/utils';

const LIME = 'hsl(78 90% 47%)';
const COLORS = [LIME, 'hsl(217 91% 60%)', 'hsl(38 92% 50%)', 'hsl(330 81% 60%)'];

interface AnalyticsOverview {
  users?: number;
  videos?: number;
  audiobooks?: number;
  books?: number;
  olympiads?: number;
  growth?: Array<{ label: string; value: number }>;
}

const tooltipStyle = {
  background: 'hsl(var(--popover))',
  border: '1px solid hsl(var(--border))',
  borderRadius: '0.5rem',
  fontSize: 12,
};

const PLACEHOLDER_GROWTH = [
  { label: 'Yan', value: 0 }, { label: 'Fev', value: 0 }, { label: 'Mar', value: 0 },
  { label: 'Apr', value: 0 }, { label: 'May', value: 0 }, { label: 'Iyun', value: 0 },
];

export default function AnalyticsPage() {
  const { data: overview, isLoading } = useQuery({
    queryKey: ['analytics-overview'],
    queryFn: () => analyticsApi.overview() as Promise<AnalyticsOverview>,
  });

  return (
    <div className="container mx-auto max-w-screen-2xl px-6 py-8">
      <PageHeader eyebrow="Hisobotlar" title="Analitika" />

      <div className="mb-6 grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-4">
        <StatTile icon={<Users />} label="Foydalanuvchilar" value={overview?.users ?? 0} loading={isLoading} idx={0} />
        <StatTile icon={<Video />} label="Videolar" value={overview?.videos ?? 0} loading={isLoading} idx={1} />
        <StatTile icon={<Headphones />} label="Audiokitoblar" value={overview?.audiobooks ?? 0} loading={isLoading} idx={2} />
        <StatTile icon={<BookOpen />} label="Kitoblar" value={overview?.books ?? 0} loading={isLoading} idx={3} />
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Card className="p-5">
          <CardHeader className="p-0 pb-4">
            <CardTitle className="flex items-center gap-2 text-base">
              <TrendingUp className="h-4 w-4 text-primary" /> Foydalanuvchilar o&apos;sishi
            </CardTitle>
          </CardHeader>
          {isLoading ? (
            <Skeleton className="h-64 w-full rounded-lg" />
          ) : (
            <div className="h-64 w-full">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={overview?.growth ?? PLACEHOLDER_GROWTH} margin={{ top: 5, right: 5, left: -20, bottom: 0 }}>
                  <defs>
                    <linearGradient id="ag" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor={LIME} stopOpacity={0.35} />
                      <stop offset="95%" stopColor={LIME} stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" vertical={false} />
                  <XAxis dataKey="label" stroke="hsl(var(--muted-foreground))" fontSize={11} tickLine={false} axisLine={false} />
                  <YAxis stroke="hsl(var(--muted-foreground))" fontSize={11} tickLine={false} axisLine={false} width={32} />
                  <Tooltip contentStyle={tooltipStyle} />
                  <Area type="monotone" dataKey="value" stroke={LIME} strokeWidth={2} fill="url(#ag)" />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          )}
        </Card>

        <Card className="p-5">
          <CardHeader className="p-0 pb-4">
            <CardTitle className="flex items-center gap-2 text-base">
              <BarChart3 className="h-4 w-4 text-primary" /> Kontent taqsimoti
            </CardTitle>
          </CardHeader>
          {isLoading ? (
            <Skeleton className="h-64 w-full rounded-lg" />
          ) : (
            <div className="h-64 w-full">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart
                  data={[
                    { label: 'Videolar', value: overview?.videos ?? 0 },
                    { label: 'Audio', value: overview?.audiobooks ?? 0 },
                    { label: 'Kitoblar', value: overview?.books ?? 0 },
                    { label: 'Konkurs', value: overview?.olympiads ?? 0 },
                  ]}
                  margin={{ top: 5, right: 5, left: -20, bottom: 0 }}
                >
                  <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" vertical={false} />
                  <XAxis dataKey="label" stroke="hsl(var(--muted-foreground))" fontSize={11} tickLine={false} axisLine={false} />
                  <YAxis stroke="hsl(var(--muted-foreground))" fontSize={11} tickLine={false} axisLine={false} width={32} />
                  <Tooltip contentStyle={tooltipStyle} cursor={{ fill: 'hsl(var(--accent))' }} />
                  <Bar dataKey="value" radius={[6, 6, 0, 0]}>
                    {COLORS.map((c, i) => <Cell key={i} fill={c} />)}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            </div>
          )}
        </Card>
      </div>
    </div>
  );
}

function StatTile({
  icon, label, value, loading, idx,
}: {
  icon: React.ReactNode; label: string; value: number; loading: boolean; idx: number;
}) {
  const colors = ['text-primary bg-primary/10', 'text-info bg-info/10', 'text-warning bg-warning/10', 'text-success bg-success/10'];
  return (
    <Card className="p-4">
      {loading ? (
        <>
          <Skeleton className="mb-3 h-10 w-10 rounded-lg" />
          <Skeleton className="h-3 w-20" />
          <Skeleton className="mt-2 h-7 w-16" />
        </>
      ) : (
        <>
          <div className={cn('mb-3 flex h-10 w-10 items-center justify-center rounded-lg [&_svg]:size-5', colors[idx % 4])}>
            {icon}
          </div>
          <p className="text-xs font-medium text-muted-foreground">{label}</p>
          <p className="mt-1 text-2xl font-bold tabular-nums">{formatCompact(value)}</p>
        </>
      )}
    </Card>
  );
}
