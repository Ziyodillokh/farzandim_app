'use client';

import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Search, MoreHorizontal, Eye, Ban, AlertTriangle, ChevronLeft, ChevronRight, UserPlus } from 'lucide-react';
import { toast } from 'sonner';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Skeleton } from '@/components/ui/skeleton';
import { Separator } from '@/components/ui/separator';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
  DropdownMenuSeparator,
  DropdownMenuLabel,
} from '@/components/ui/dropdown-menu';
import { usersApi, type UsersListParams } from '@/lib/api/admin.api';
import { cn, formatPhone, formatRelative, initials } from '@/lib/utils';
import type { AdminUserListItem } from '@/types/api.types';

const ROLE_FILTERS = [
  { value: '', label: 'Barcha rollar' },
  { value: 'parent', label: 'Ota-ona' },
  { value: 'child', label: 'Bola' },
];
const STATUS_FILTERS = [
  { value: '', label: 'Barcha statuslar' },
  { value: 'active', label: 'Faol' },
  { value: 'blocked', label: 'Bloklangan' },
];
const PLAN_FILTERS = [
  { value: '', label: 'Barcha obunalar' },
  { value: 'free', label: 'Free' },
  { value: 'basic', label: 'Basic' },
  { value: 'standard', label: 'Standard' },
  { value: 'premium', label: 'Premium' },
];

export default function UsersPage() {
  const [q, setQ] = useState('');
  const [role, setRole] = useState('');
  const [status, setStatus] = useState('');
  const [plan, setPlan] = useState('');
  const [page, setPage] = useState(1);
  const limit = 20;

  const params: UsersListParams = { q, role, status, plan, page, limit };
  const { data, isLoading, isFetching } = useQuery({
    queryKey: ['users', params],
    queryFn: () => usersApi.list(params),
    placeholderData: (prev) => prev,
  });

  return (
    <div className="container mx-auto max-w-screen-2xl px-6 py-8">
      {/* Header */}
      <div className="mb-6 flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="text-sm text-muted-foreground">Foydalanuvchilar boshqaruvi</p>
          <h2 className="text-2xl font-bold tracking-tight">
            Hammasi <span className="text-muted-foreground">({data?.total ?? 0})</span>
          </h2>
        </div>
        <Button>
          <UserPlus className="h-4 w-4" />
          Foydalanuvchi qo&apos;shish
        </Button>
      </div>

      {/* Filter bar */}
      <Card className="mb-4 p-4">
        <div className="flex flex-wrap items-center gap-3">
          <div className="min-w-[240px] flex-1">
            <Input
              icon={<Search />}
              placeholder="Ism, telefon yoki email..."
              value={q}
              onChange={(e) => {
                setQ(e.target.value);
                setPage(1);
              }}
            />
          </div>
          <FilterSelect value={role} onChange={(v) => { setRole(v); setPage(1); }} options={ROLE_FILTERS} />
          <FilterSelect value={status} onChange={(v) => { setStatus(v); setPage(1); }} options={STATUS_FILTERS} />
          <FilterSelect value={plan} onChange={(v) => { setPlan(v); setPage(1); }} options={PLAN_FILTERS} />
        </div>
      </Card>

      {/* Table */}
      <Card className="overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border bg-muted/30 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                <th className="px-4 py-3 text-left">Ism familiya</th>
                <th className="px-4 py-3 text-left">Telefon</th>
                <th className="px-4 py-3 text-left">Rol</th>
                <th className="px-4 py-3 text-left">Status</th>
                <th className="px-4 py-3 text-left">Obuna</th>
                <th className="px-4 py-3 text-left">Oxirgi faollik</th>
                <th className="px-4 py-3 w-10" />
              </tr>
            </thead>
            <tbody className={cn(isFetching && !isLoading && 'opacity-60 transition-opacity')}>
              {isLoading ? (
                Array.from({ length: 6 }).map((_, i) => <RowSkeleton key={i} />)
              ) : data?.items.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-4 py-16 text-center">
                    <p className="text-muted-foreground">Foydalanuvchi topilmadi</p>
                  </td>
                </tr>
              ) : (
                data?.items.map((u) => <UserRow key={u.id} user={u} />)
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        {data && data.totalPages > 1 && (
          <div className="flex items-center justify-between border-t border-border px-4 py-3">
            <p className="text-xs text-muted-foreground">
              {(data.page - 1) * limit + 1}–{Math.min(data.page * limit, data.total)} / {data.total}
            </p>
            <div className="flex items-center gap-1">
              <Button
                variant="outline"
                size="icon-sm"
                disabled={data.page <= 1}
                onClick={() => setPage((p) => Math.max(1, p - 1))}
              >
                <ChevronLeft className="h-4 w-4" />
              </Button>
              <div className="rounded-md bg-muted px-2.5 py-1 text-xs font-semibold tabular-nums">
                {data.page} / {data.totalPages}
              </div>
              <Button
                variant="outline"
                size="icon-sm"
                disabled={data.page >= data.totalPages}
                onClick={() => setPage((p) => p + 1)}
              >
                <ChevronRight className="h-4 w-4" />
              </Button>
            </div>
          </div>
        )}
      </Card>
    </div>
  );
}

/* ─── User row ─── */

function UserRow({ user }: { user: AdminUserListItem }) {
  const isChild = user.kind === 'child' || user.role === 'CHILD';
  const isActive = user.status === 'active';

  const handleBlock = async () => {
    try {
      isActive ? await usersApi.block(user.id) : await usersApi.unblock(user.id);
      toast.success(isActive ? 'Bloklandi' : 'Blok olindi');
    } catch {
      toast.error("Amalni bajarib bo'lmadi");
    }
  };

  return (
    <tr className="border-b border-border last:border-0 transition-colors hover:bg-accent/40">
      <td className="px-4 py-3">
        <div className="flex items-center gap-3">
          <Avatar className="h-9 w-9">
            <AvatarFallback className="text-xs">{initials(user.name)}</AvatarFallback>
          </Avatar>
          <div className="min-w-0">
            <p className="truncate font-semibold">{user.name}</p>
            {user.email && (
              <p className="truncate text-xs text-muted-foreground">{user.email}</p>
            )}
          </div>
        </div>
      </td>
      <td className="px-4 py-3 font-mono text-xs text-muted-foreground">{formatPhone(user.phone)}</td>
      <td className="px-4 py-3">
        <Badge variant={isChild ? 'info' : 'secondary'} size="sm">
          {isChild ? 'Bola' : 'Ota-ona'}
        </Badge>
      </td>
      <td className="px-4 py-3">
        <Badge variant={isActive ? 'success' : 'destructive'} size="sm">
          <span className={cn('h-1.5 w-1.5 rounded-full', isActive ? 'bg-success' : 'bg-destructive')} />
          {isActive ? 'Faol' : 'Bloklangan'}
        </Badge>
      </td>
      <td className="px-4 py-3 text-muted-foreground">{user.planLabel || 'Free'}</td>
      <td className="px-4 py-3 text-xs text-muted-foreground">{formatRelative(user.lastActivityAt)}</td>
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
              <Eye /> Batafsil
            </DropdownMenuItem>
            <DropdownMenuItem>
              <AlertTriangle /> Ogohlantirish
            </DropdownMenuItem>
            <DropdownMenuSeparator />
            <DropdownMenuItem onClick={handleBlock} className={isActive ? 'text-destructive focus:text-destructive' : ''}>
              <Ban /> {isActive ? 'Bloklash' : 'Blokdan chiqarish'}
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </td>
    </tr>
  );
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
        <Button variant="outline" className="min-w-[160px] justify-between">
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
      <td className="px-4 py-3">
        <div className="flex items-center gap-3">
          <Skeleton className="h-9 w-9 rounded-full" />
          <div className="space-y-1.5">
            <Skeleton className="h-3 w-32" />
            <Skeleton className="h-2.5 w-24" />
          </div>
        </div>
      </td>
      <td className="px-4 py-3"><Skeleton className="h-3 w-28" /></td>
      <td className="px-4 py-3"><Skeleton className="h-5 w-14 rounded-full" /></td>
      <td className="px-4 py-3"><Skeleton className="h-5 w-16 rounded-full" /></td>
      <td className="px-4 py-3"><Skeleton className="h-3 w-12" /></td>
      <td className="px-4 py-3"><Skeleton className="h-3 w-20" /></td>
      <td className="px-4 py-3"><Skeleton className="h-7 w-7 rounded-md" /></td>
    </tr>
  );
}
