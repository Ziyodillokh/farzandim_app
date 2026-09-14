'use client';

import { useQuery } from '@tanstack/react-query';
import { format } from 'date-fns';
import {
  Baby,
  CalendarDays,
  Gift,
  Mail,
  Phone,
  Smartphone,
  Sparkles,
  Wifi,
  BatteryMedium,
  Trophy,
  Flame,
  Coins,
} from 'lucide-react';
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from '@/components/ui/sheet';
import { Avatar, AvatarImage, AvatarFallback } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { Separator } from '@/components/ui/separator';
import { usersApi } from '@/lib/api/admin.api';
import { cn, formatPhone, formatRelative, initials } from '@/lib/utils';
import type { AdminUserListItem } from '@/types/api.types';

/**
 * Foydalanuvchi "Batafsil" — o'ng tomondan chiqadigan panel.
 * Ota-ona → /admin/users/:id (obuna, bolalar, to'lovlar soni);
 * bola     → /admin/users/child-profiles/:id (qurilma, XP/DON, qiziqishlar).
 */
export function UserDetailSheet({
  user,
  open,
  onOpenChange,
}: {
  user: AdminUserListItem;
  open: boolean;
  onOpenChange: (v: boolean) => void;
}) {
  const isChild = user.kind === 'child' || user.role === 'CHILD';

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent className="w-full overflow-y-auto sm:max-w-lg">
        <SheetHeader className="text-left">
          <div className="flex items-center gap-3">
            <Avatar className="h-12 w-12">
              {user.avatarUrl ? <AvatarImage src={user.avatarUrl} alt={user.name} /> : null}
              <AvatarFallback className="bg-primary/10 text-sm font-semibold text-primary">
                {initials(user.name)}
              </AvatarFallback>
            </Avatar>
            <div className="min-w-0">
              <SheetTitle className="truncate">{user.name}</SheetTitle>
              {/* Badge = <div>; SheetDescription <p> ichiga qo'yib bo'lmaydi (hydration) */}
              <SheetDescription className="sr-only">
                {isChild ? 'Bola' : 'Ota-ona'} profili
              </SheetDescription>
              <div className="mt-1 flex flex-wrap items-center gap-1.5">
                <Badge variant={isChild ? 'info' : 'secondary'} size="sm">
                  {isChild ? 'Bola' : 'Ota-ona'}
                </Badge>
                <Badge variant={user.status === 'active' ? 'success' : 'destructive'} size="sm">
                  {user.status === 'active' ? 'Faol' : 'Bloklangan'}
                </Badge>
              </div>
            </div>
          </div>
        </SheetHeader>

        <div className="mt-2 flex flex-col gap-5">
          {isChild ? <ChildDetail id={user.id} enabled={open} /> : <ParentDetail id={user.id} enabled={open} />}
        </div>
      </SheetContent>
    </Sheet>
  );
}

/* ─── Ota-ona ─── */

function ParentDetail({ id, enabled }: { id: string; enabled: boolean }) {
  const { data, isLoading, isError } = useQuery({
    queryKey: ['user-detail', id],
    queryFn: () => usersApi.detail(id),
    enabled,
  });

  if (isLoading) return <DetailSkeleton />;
  if (isError || !data) return <ErrorNote />;

  const sub = data.subscription;
  const subExpired = sub?.expiresAt ? new Date(sub.expiresAt).getTime() < Date.now() : false;

  return (
    <>
      <Section title="Aloqa">
        <InfoRow icon={Phone} label="Telefon" value={data.phone ? formatPhone(data.phone) : '—'} mono />
        <InfoRow icon={Mail} label="Email" value={data.email ?? '—'} />
        <InfoRow icon={CalendarDays} label="Ro'yxatdan o'tgan" value={fmtDate(data.createdAt)} />
        <InfoRow icon={CalendarDays} label="Oxirgi faollik" value={formatRelative(data.lastActivityAt)} />
      </Section>

      <Section title="Obuna">
        {sub ? (
          <div className="rounded-xl border border-border bg-muted/30 p-3">
            <div className="flex items-center justify-between gap-2">
              <div className="flex items-center gap-2">
                <Sparkles className="h-4 w-4 text-primary" />
                <span className="font-semibold">{sub.planName}</span>
              </div>
              <div className="flex items-center gap-1.5">
                {sub.isTrial && (
                  <Badge variant="warning" size="sm">
                    <Gift className="h-3 w-3" /> Demo
                  </Badge>
                )}
                <Badge variant={subExpired ? 'destructive' : 'success'} size="sm">
                  {subExpired ? 'Tugagan' : 'Faol'}
                </Badge>
              </div>
            </div>
            <div className="mt-2 grid grid-cols-2 gap-2 text-xs text-muted-foreground">
              <div>
                <p className="text-2xs uppercase tracking-wider">Boshlangan</p>
                <p className="font-medium text-foreground">{fmtDate(sub.startedAt)}</p>
              </div>
              <div>
                <p className="text-2xs uppercase tracking-wider">Tugaydi</p>
                <p className="font-medium text-foreground">
                  {sub.expiresAt ? fmtDate(sub.expiresAt) : 'Muddatsiz'}
                </p>
              </div>
            </div>
          </div>
        ) : (
          <p className="text-sm text-muted-foreground">
            Faol obuna yo&apos;q — <span className="font-medium text-foreground">Free</span>
          </p>
        )}
        <div className="flex flex-wrap gap-x-4 gap-y-1 text-xs text-muted-foreground">
          <span>To&apos;lovlar: <b className="text-foreground">{data.paymentsCount}</b></span>
          <span>Ro&apos;yxat demo: <b className="text-foreground">{data.trialUsed ? 'ishlatilgan' : 'ishlatilmagan'}</b></span>
        </div>
      </Section>

      <Section title={`Bolalar (${data.childrenCount})`}>
        {data.children.length === 0 ? (
          <p className="text-sm text-muted-foreground">Bola qo&apos;shilmagan</p>
        ) : (
          <ul className="flex flex-col gap-2">
            {data.children.map((c) => (
              <li
                key={c.id}
                className="flex items-center gap-3 rounded-xl border border-border p-2.5"
              >
                <Avatar className="h-9 w-9">
                  {c.avatarUrl ? <AvatarImage src={c.avatarUrl} alt={c.name} /> : null}
                  <AvatarFallback className="text-xs">{initials(c.name)}</AvatarFallback>
                </Avatar>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-semibold">
                    {c.name}
                    {c.age != null && (
                      <span className="ml-1.5 text-xs font-normal text-muted-foreground">{c.age} yosh</span>
                    )}
                  </p>
                  <p className="truncate text-xs text-muted-foreground">
                    {c.isConnected ? 'Qurilma ulangan' : 'Qurilma ulanmagan'}
                    {c.lastSeenAt ? ` · ${formatRelative(c.lastSeenAt)}` : ''}
                  </p>
                </div>
                {c.familyCode && (
                  <code className="rounded-md bg-muted px-1.5 py-0.5 font-mono text-2xs">{c.familyCode}</code>
                )}
              </li>
            ))}
          </ul>
        )}
      </Section>
    </>
  );
}

/* ─── Bola ─── */

function ChildDetail({ id, enabled }: { id: string; enabled: boolean }) {
  const { data, isLoading, isError } = useQuery({
    queryKey: ['child-profile', id],
    queryFn: () => usersApi.childProfile(id),
    enabled,
  });

  if (isLoading) return <DetailSkeleton />;
  if (isError || !data) return <ErrorNote />;

  const p = data.profile;

  return (
    <>
      <Section title="Profil">
        <InfoRow icon={Baby} label="Yosh / jins" value={[data.age != null ? `${data.age} yosh` : null, data.gender].filter(Boolean).join(' · ') || '—'} />
        <InfoRow icon={Phone} label="Telefon" value={data.phone ? formatPhone(data.phone) : '—'} mono />
        <InfoRow icon={CalendarDays} label="Qo'shilgan" value={fmtDate(data.createdAt)} />
        <InfoRow icon={CalendarDays} label="Oxirgi ko'rilgan" value={formatRelative(data.lastSeenAt)} />
        {data.parent && (
          <InfoRow
            icon={Phone}
            label="Ota-ona"
            value={`${data.parent.name ?? '—'}${data.parent.phone ? ` · ${formatPhone(data.parent.phone)}` : ''}`}
          />
        )}
        {data.interests.length > 0 && (
          <div className="flex flex-wrap gap-1.5 pt-1">
            {data.interests.map((i) => (
              <Badge key={i} variant="outline" size="sm">{i}</Badge>
            ))}
          </div>
        )}
      </Section>

      {p && (
        <Section title="Gamifikatsiya">
          <div className="grid grid-cols-3 gap-2">
            <Stat icon={Trophy} label="Daraja" value={`${p.level}`} sub={`${p.xp} XP`} />
            <Stat icon={Coins} label="DON" value={`${p.donBalance}`} />
            <Stat icon={Flame} label="Streak" value={`${p.streakDays}`} sub="kun" />
          </div>
        </Section>
      )}

      <Section title="Qurilma">
        <InfoRow
          icon={Smartphone}
          label="Model"
          value={[clean(data.device.model), androidLabel(data.device.androidVersion)].filter(Boolean).join(' · ') || '—'}
        />
        <InfoRow icon={Sparkles} label="Ilova versiyasi" value={clean(data.device.appVersion) ?? '—'} mono />
        <InfoRow
          icon={BatteryMedium}
          label="Batareya"
          value={data.device.batteryLevel != null ? `${data.device.batteryLevel}%${data.device.isCharging ? ' · quvvatlanmoqda' : ''}` : '—'}
        />
        <InfoRow icon={Wifi} label="Wi-Fi" value={clean(data.device.wifiName) ?? '—'} />
        <div className="flex items-center gap-2 pt-1">
          <Badge variant={data.isConnected ? 'success' : 'secondary'} size="sm">
            {data.isConnected ? 'Ulangan' : 'Ulanmagan'}
          </Badge>
          {data.familyCode && (
            <code className="rounded-md bg-muted px-1.5 py-0.5 font-mono text-2xs">{data.familyCode}</code>
          )}
        </div>
      </Section>
    </>
  );
}

/* ─── Kichik bloklar ─── */

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="flex flex-col gap-2">
      <p className="text-2xs font-semibold uppercase tracking-[0.12em] text-muted-foreground">{title}</p>
      {children}
      <Separator className="mt-1" />
    </div>
  );
}

function InfoRow({
  icon: Icon,
  label,
  value,
  mono,
}: {
  icon: typeof Phone;
  label: string;
  value: string;
  mono?: boolean;
}) {
  return (
    <div className="flex items-center gap-3 text-sm">
      <Icon className="h-4 w-4 shrink-0 text-muted-foreground" />
      <span className="w-32 shrink-0 text-muted-foreground">{label}</span>
      <span className={cn('min-w-0 flex-1 truncate font-medium', mono && 'font-mono text-xs')}>{value}</span>
    </div>
  );
}

function Stat({
  icon: Icon,
  label,
  value,
  sub,
}: {
  icon: typeof Trophy;
  label: string;
  value: string;
  sub?: string;
}) {
  return (
    <div className="rounded-xl border border-border bg-muted/30 p-3">
      <div className="flex items-center gap-1.5 text-2xs uppercase tracking-wider text-muted-foreground">
        <Icon className="h-3.5 w-3.5" /> {label}
      </div>
      <p className="mt-1 text-lg font-bold tabular-nums leading-none">
        {value}
        {sub && <span className="ml-1 text-xs font-normal text-muted-foreground">{sub}</span>}
      </p>
    </div>
  );
}

function DetailSkeleton() {
  return (
    <div className="flex flex-col gap-3">
      {Array.from({ length: 6 }).map((_, i) => (
        <Skeleton key={i} className="h-5 w-full" />
      ))}
    </div>
  );
}

function ErrorNote() {
  return <p className="text-sm text-destructive">Ma&apos;lumotni yuklab bo&apos;lmadi</p>;
}

/** Qurilma maydonlari ba'zan "null"/"null null" satr bo'lib keladi (eski
 *  bola ilovasi) — bo'sh deb hisoblaymiz. */
function clean(v: string | null | undefined): string | null {
  if (!v) return null;
  const t = v.replace(/null/gi, '').replace(/s+/g, ' ').trim();
  return t.length > 0 ? t : null;
}

function androidLabel(v: string | null | undefined): string | null {
  const t = clean(v);
  if (!t) return null;
  return /^android/i.test(t) ? t : `Android ${t}`;
}

function fmtDate(iso: string | null | undefined): string {
  if (!iso) return '—';
  const d = new Date(iso);
  return isNaN(d.getTime()) ? '—' : format(d, 'dd.MM.yyyy HH:mm');
}
