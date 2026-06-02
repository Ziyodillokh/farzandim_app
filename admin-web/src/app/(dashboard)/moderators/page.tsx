'use client';

import { useState } from 'react';
import { useQuery, useQueryClient, useMutation } from '@tanstack/react-query';
import {
  Search, MoreHorizontal, Pencil, Ban, KeyRound, Trash2, ShieldCheck, ShieldOff, UserPlus,
} from 'lucide-react';
import { toast } from 'sonner';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Skeleton } from '@/components/ui/skeleton';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
  DropdownMenuSeparator,
  DropdownMenuLabel,
} from '@/components/ui/dropdown-menu';
import { PageHeader } from '@/components/common/page-header';
import { DataPagination } from '@/components/common/data-pagination';
import { EmptyState } from '@/components/common/empty-state';
import { moderatorsApi } from '@/lib/api/admin.api';
import { cn, formatPhone, formatRelative, initials } from '@/lib/utils';
import { getApiErrorMessage } from '@/lib/api/client';
import { ModeratorFormModal } from '@/components/moderators/moderator-form-modal';
import type { Moderator } from '@/types/api.types';

const ROLE_CFG: Record<string, { label: string; variant: 'default' | 'info' | 'warning' | 'secondary' }> = {
  super_admin: { label: 'Super Admin', variant: 'default' },
  finance: { label: 'Moliya', variant: 'warning' },
  content_maker: { label: 'Kontent', variant: 'info' },
  support: { label: 'Qo\'llab-quvvatlash', variant: 'secondary' },
};

export default function ModeratorsPage() {
  const qc = useQueryClient();
  const [q, setQ] = useState('');
  const [page, setPage] = useState(1);
  const [createOpen, setCreateOpen] = useState(false);
  const limit = 20;

  const params = { q, page, limit };
  const { data, isLoading, isFetching } = useQuery({
    queryKey: ['moderators', params],
    queryFn: () => moderatorsApi.list(params),
    placeholderData: (prev) => prev,
  });

  const invalidate = () => qc.invalidateQueries({ queryKey: ['moderators'] });

  const block = useMutation({
    mutationFn: ({ id, blocked }: { id: string; blocked: boolean }) =>
      blocked ? moderatorsApi.unblock(id) : moderatorsApi.block(id),
    onSuccess: (_d, v) => {
      toast.success(v.blocked ? 'Blokdan chiqarildi' : 'Bloklandi');
      invalidate();
    },
    onError: (e) => toast.error(getApiErrorMessage(e)),
  });

  const resetPassword = useMutation({
    mutationFn: (id: string) => moderatorsApi.resetPassword(id),
    onSuccess: (res) => {
      toast.success('Yangi parol', {
        description: res.password,
        duration: 12000,
      });
    },
    onError: (e) => toast.error(getApiErrorMessage(e)),
  });

  const remove = useMutation({
    mutationFn: (id: string) => moderatorsApi.remove(id),
    onSuccess: () => {
      toast.success("O'chirildi");
      invalidate();
    },
    onError: (e) => toast.error(getApiErrorMessage(e)),
  });

  return (
    <div className="container mx-auto max-w-screen-2xl px-6 py-8">
      <PageHeader
        eyebrow="Jamoa boshqaruvi"
        title="Moderatorlar"
        count={data?.total}
        actions={
          <Button onClick={() => setCreateOpen(true)}>
            <UserPlus className="h-4 w-4" /> Yangi moderator
          </Button>
        }
      />

      <ModeratorFormModal
        open={createOpen}
        onOpenChange={setCreateOpen}
        onSuccess={invalidate}
      />

      {/* Filter bar */}
      <Card className="mb-4 p-4">
        <div className="flex flex-wrap items-center gap-3">
          <div className="min-w-[240px] flex-1">
            <Input
              icon={<Search />}
              placeholder="Ism yoki email..."
              value={q}
              onChange={(e) => { setQ(e.target.value); setPage(1); }}
            />
          </div>
        </div>
      </Card>

      {/* Table */}
      <Card className="overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border bg-muted/30 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                <th className="px-4 py-3 text-left">Moderator</th>
                <th className="px-4 py-3 text-left">Telefon</th>
                <th className="px-4 py-3 text-left">Rol</th>
                <th className="px-4 py-3 text-left">Ruxsatlar</th>
                <th className="px-4 py-3 text-left">Status</th>
                <th className="px-4 py-3 text-left">2FA</th>
                <th className="px-4 py-3 text-left">Oxirgi faollik</th>
                <th className="px-4 py-3 w-10" />
              </tr>
            </thead>
            <tbody className={cn(isFetching && !isLoading && 'opacity-60 transition-opacity')}>
              {isLoading ? (
                Array.from({ length: 6 }).map((_, i) => <RowSkeleton key={i} />)
              ) : !data || data.items.length === 0 ? (
                <tr>
                  <td colSpan={8} className="p-0">
                    <EmptyState
                      icon={<ShieldCheck />}
                      title="Moderator topilmadi"
                      description="Hozircha moderator yo'q yoki qidiruvga mos kelmadi. Yangi moderator qo'shing."
                    />
                  </td>
                </tr>
              ) : (
                data.items.map((m) => (
                  <ModeratorRow
                    key={m.id}
                    moderator={m}
                    onToggleBlock={() => block.mutate({ id: m.id, blocked: m.status === 'blocked' })}
                    onResetPassword={() => resetPassword.mutate(m.id)}
                    onRemove={() => remove.mutate(m.id)}
                  />
                ))
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

/* ─── Moderator row ─── */

function ModeratorRow({
  moderator,
  onToggleBlock,
  onResetPassword,
  onRemove,
}: {
  moderator: Moderator;
  onToggleBlock: () => void;
  onResetPassword: () => void;
  onRemove: () => void;
}) {
  const isActive = moderator.status === 'active';
  const roleCfg = ROLE_CFG[moderator.moderatorRoleKey] ?? {
    label: moderator.moderatorRoleKey,
    variant: 'secondary' as const,
  };

  return (
    <tr className="border-b border-border last:border-0 transition-colors hover:bg-accent/40">
      <td className="px-4 py-3">
        <div className="flex items-center gap-3">
          <Avatar className="h-9 w-9">
            <AvatarFallback className="text-xs">{initials(moderator.name)}</AvatarFallback>
          </Avatar>
          <div className="min-w-0">
            <p className="truncate font-semibold">{moderator.name}</p>
            <p className="truncate text-xs text-muted-foreground">{moderator.email}</p>
          </div>
        </div>
      </td>
      <td className="px-4 py-3 font-mono text-xs text-muted-foreground">{formatPhone(moderator.phone)}</td>
      <td className="px-4 py-3">
        <Badge variant={roleCfg.variant} size="sm">{roleCfg.label}</Badge>
      </td>
      <td className="px-4 py-3 text-muted-foreground">
        {moderator.permissions.length} ta
      </td>
      <td className="px-4 py-3">
        <Badge variant={isActive ? 'success' : 'destructive'} size="sm">
          <span className={cn('h-1.5 w-1.5 rounded-full', isActive ? 'bg-success' : 'bg-destructive')} />
          {isActive ? 'Faol' : 'Bloklangan'}
        </Badge>
      </td>
      <td className="px-4 py-3">
        {moderator.twoFactorEnabled ? (
          <span className="inline-flex items-center gap-1 text-xs font-medium text-success">
            <ShieldCheck className="h-4 w-4" /> Yoqilgan
          </span>
        ) : (
          <span className="inline-flex items-center gap-1 text-xs font-medium text-muted-foreground">
            <ShieldOff className="h-4 w-4" /> O&apos;chiq
          </span>
        )}
      </td>
      <td className="px-4 py-3 text-xs text-muted-foreground">{formatRelative(moderator.lastActivityAt)}</td>
      <td className="px-4 py-3">
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" size="icon-sm" aria-label="Amallar">
              <MoreHorizontal className="h-4 w-4" />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuLabel>Amallar</DropdownMenuLabel>
            <DropdownMenuItem>
              <Pencil /> Tahrirlash
            </DropdownMenuItem>
            <DropdownMenuItem onClick={onResetPassword}>
              <KeyRound /> Parolni tiklash
            </DropdownMenuItem>
            <DropdownMenuItem
              onClick={onToggleBlock}
              className={isActive ? 'text-destructive focus:text-destructive' : ''}
            >
              <Ban /> {isActive ? 'Bloklash' : 'Blokdan chiqarish'}
            </DropdownMenuItem>
            <DropdownMenuSeparator />
            <DropdownMenuItem onClick={onRemove} className="text-destructive focus:text-destructive">
              <Trash2 /> O&apos;chirish
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </td>
    </tr>
  );
}

/* ─── Row skeleton ─── */

function RowSkeleton() {
  return (
    <tr className="border-b border-border">
      <td className="px-4 py-3">
        <div className="flex items-center gap-3">
          <Skeleton className="h-9 w-9 rounded-full" />
          <div className="space-y-1.5">
            <Skeleton className="h-3 w-32" />
            <Skeleton className="h-2.5 w-40" />
          </div>
        </div>
      </td>
      <td className="px-4 py-3"><Skeleton className="h-3 w-28" /></td>
      <td className="px-4 py-3"><Skeleton className="h-5 w-20 rounded-full" /></td>
      <td className="px-4 py-3"><Skeleton className="h-3 w-10" /></td>
      <td className="px-4 py-3"><Skeleton className="h-5 w-16 rounded-full" /></td>
      <td className="px-4 py-3"><Skeleton className="h-3 w-16" /></td>
      <td className="px-4 py-3"><Skeleton className="h-3 w-20" /></td>
      <td className="px-4 py-3"><Skeleton className="h-7 w-7 rounded-md" /></td>
    </tr>
  );
}
