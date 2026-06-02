'use client';

import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { ScrollText, CheckCircle2, XCircle, Globe } from 'lucide-react';
import { Card } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import {
  DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { PageHeader } from '@/components/common/page-header';
import { DataPagination } from '@/components/common/data-pagination';
import { EmptyState } from '@/components/common/empty-state';
import { auditApi } from '@/lib/api/admin.api';
import { ChevronDown } from 'lucide-react';
import { formatRelative } from '@/lib/utils';
import type { AuditLogEntry } from '@/types/api.types';

export default function AuditLogPage() {
  const [action, setAction] = useState('');
  const [page, setPage] = useState(1);
  const limit = 25;

  const { data: actions } = useQuery({
    queryKey: ['audit-actions'],
    queryFn: () => auditApi.actions(),
  });

  const { data, isLoading } = useQuery({
    queryKey: ['audit-log', { action, page, limit }],
    queryFn: () => auditApi.list({ action: action || undefined, page, limit }),
    placeholderData: (p) => p,
  });

  return (
    <div className="container mx-auto max-w-screen-2xl px-6 py-8">
      <PageHeader
        eyebrow="Xavfsizlik"
        title="Audit jurnali"
        count={data?.total}
        actions={
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="outline" className="min-w-[180px] justify-between">
                {action || 'Barcha amallar'}
                <ChevronDown className="h-4 w-4" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="max-h-72 overflow-y-auto">
              <DropdownMenuItem onClick={() => { setAction(''); setPage(1); }}>Barcha amallar</DropdownMenuItem>
              {actions?.map((a) => (
                <DropdownMenuItem key={a} onClick={() => { setAction(a); setPage(1); }} className="font-mono text-xs">
                  {a}
                </DropdownMenuItem>
              ))}
            </DropdownMenuContent>
          </DropdownMenu>
        }
      />

      <Card className="overflow-hidden">
        {isLoading ? (
          <div className="divide-y divide-border">
            {Array.from({ length: 8 }).map((_, i) => (
              <div key={i} className="flex items-center gap-4 p-4">
                <Skeleton className="h-9 w-9 rounded-full" />
                <div className="flex-1 space-y-2">
                  <Skeleton className="h-3 w-1/2" />
                  <Skeleton className="h-2.5 w-1/3" />
                </div>
              </div>
            ))}
          </div>
        ) : !data || data.items.length === 0 ? (
          <EmptyState icon={<ScrollText />} title="Yozuv topilmadi" description="Bu filtrda audit yozuvi yo'q." />
        ) : (
          <div className="divide-y divide-border">
            {data.items.map((entry) => (
              <AuditRow key={entry.id} entry={entry} />
            ))}
          </div>
        )}
        {data && (
          <DataPagination page={data.page} totalPages={data.totalPages} total={data.total} limit={limit} onPageChange={setPage} />
        )}
      </Card>
    </div>
  );
}

function AuditRow({ entry }: { entry: AuditLogEntry }) {
  const ok = entry.status === 'success';
  return (
    <div className="flex items-start gap-4 p-4 transition-colors hover:bg-accent/40">
      <div
        className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-full ${
          ok ? 'bg-success/10 text-success' : 'bg-destructive/10 text-destructive'
        }`}
      >
        {ok ? <CheckCircle2 className="h-4 w-4" /> : <XCircle className="h-4 w-4" />}
      </div>
      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-center gap-2">
          <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs font-semibold">{entry.action}</code>
          {entry.resourceType && (
            <Badge variant="outline" size="sm">
              {entry.resourceType}
              {entry.resourceId ? `:${entry.resourceId.slice(0, 8)}` : ''}
            </Badge>
          )}
          <Badge variant={ok ? 'success' : 'destructive'} size="sm">{ok ? 'Muvaffaqiyatli' : 'Xato'}</Badge>
        </div>
        <div className="mt-1.5 flex flex-wrap items-center gap-3 text-xs text-muted-foreground">
          {entry.email && <span className="font-medium text-foreground">{entry.email}</span>}
          {entry.ipAddress && (
            <span className="flex items-center gap-1">
              <Globe className="h-3 w-3" /> {entry.ipAddress}
            </span>
          )}
          <span className="ml-auto">{formatRelative(entry.createdAt)}</span>
        </div>
      </div>
    </div>
  );
}
