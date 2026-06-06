'use client';

import { useEffect, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import {
  User, Lock, ShieldCheck, KeyRound, Mail, Phone, BadgeCheck,
  Globe, Plus, X, ShieldAlert,
} from 'lucide-react';
import { toast } from 'sonner';
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Badge } from '@/components/ui/badge';
import { Switch } from '@/components/ui/switch';
import { Separator } from '@/components/ui/separator';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { PageHeader } from '@/components/common/page-header';
import { authApi, securitySettingsApi } from '@/lib/api/admin.api';
import { useAuthStore } from '@/stores/auth.store';
import { getApiErrorMessage } from '@/lib/api/client';
import { initials } from '@/lib/utils';

export default function SettingsPage() {
  const user = useAuthStore((s) => s.user);

  const { data: twoFa } = useQuery({
    queryKey: ['2fa-status'],
    queryFn: () => authApi.twoFactor.status(),
  });

  return (
    <div className="container mx-auto max-w-3xl px-6 py-8">
      <PageHeader eyebrow="Hisob" title="Sozlamalar" />

      {/* Profile */}
      <Card className="mb-6">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <User className="h-5 w-5 text-primary" /> Profil ma&apos;lumotlari
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="flex items-center gap-4">
            <Avatar className="h-16 w-16">
              <AvatarFallback className="text-lg">{initials(user?.name)}</AvatarFallback>
            </Avatar>
            <div className="flex-1">
              <div className="flex items-center gap-2">
                <h3 className="text-lg font-bold">{user?.name}</h3>
                <Badge variant="default" size="sm">{user?.moderatorRoleKey}</Badge>
              </div>
              <div className="mt-1 flex flex-wrap items-center gap-x-4 gap-y-1 text-sm text-muted-foreground">
                <span className="flex items-center gap-1"><Mail className="h-3.5 w-3.5" /> {user?.email}</span>
                {user?.phone && <span className="flex items-center gap-1"><Phone className="h-3.5 w-3.5" /> {user.phone}</span>}
              </div>
            </div>
            {user?.isFullAccess && (
              <Badge variant="success" size="sm">
                <BadgeCheck className="h-3.5 w-3.5" /> To&apos;liq ruxsat
              </Badge>
            )}
          </div>
        </CardContent>
      </Card>

      {/* Password change */}
      <ChangePasswordCard />

      {/* 2FA */}
      <Card className="mt-6">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <ShieldCheck className="h-5 w-5 text-primary" /> Ikki bosqichli himoya (2FA)
          </CardTitle>
          <CardDescription>
            Hisobingizni qo&apos;shimcha himoya qatlami bilan mustahkamlang
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="flex items-center justify-between rounded-lg border border-border p-4">
            <div className="flex items-center gap-3">
              <div className={`flex h-10 w-10 items-center justify-center rounded-lg ${twoFa?.enabled ? 'bg-success/10 text-success' : 'bg-muted text-muted-foreground'}`}>
                <KeyRound className="h-5 w-5" />
              </div>
              <div>
                <p className="font-semibold">{twoFa?.enabled ? 'Yoqilgan' : 'O\'chirilgan'}</p>
                <p className="text-sm text-muted-foreground">
                  {twoFa?.enabled
                    ? `${twoFa.remainingBackupCodes} ta zaxira kod qoldi`
                    : 'TOTP authenticator orqali himoyalang'}
                </p>
              </div>
            </div>
            <Button variant={twoFa?.enabled ? 'outline' : 'default'}>
              {twoFa?.enabled ? 'O\'chirish' : 'Yoqish'}
            </Button>
          </div>
        </CardContent>
      </Card>

      {/* Xavfsizlik siyosati — IP allowlist */}
      <SecuritySettingsCard />
    </div>
  );
}

const IP_RE = /^(\d{1,3}\.){3}\d{1,3}$|^[0-9a-fA-F:]+$/;

function SecuritySettingsCard() {
  const qc = useQueryClient();
  const { data } = useQuery({
    queryKey: ['security-settings'],
    queryFn: () => securitySettingsApi.get(),
  });

  const [enabled, setEnabled] = useState(false);
  const [ips, setIps] = useState<string[]>([]);
  const [ipInput, setIpInput] = useState('');
  const [loaded, setLoaded] = useState(false);

  // Backend ma'lumoti kelganda lokal holatni bir marta to'ldiramiz.
  useEffect(() => {
    if (data && !loaded) {
      setEnabled(data.ipAllowlistEnabled);
      setIps(data.ipAllowlist);
      setLoaded(true);
    }
  }, [data, loaded]);

  const addIp = (value: string) => {
    const ip = value.trim();
    if (!ip) return;
    if (!IP_RE.test(ip)) {
      toast.error("Noto'g'ri IP manzil");
      return;
    }
    setIps((prev) => (prev.includes(ip) ? prev : [...prev, ip]));
    setIpInput('');
  };

  const mutation = useMutation({
    mutationFn: () =>
      securitySettingsApi.update({ ipAllowlistEnabled: enabled, ipAllowlist: ips }),
    onSuccess: () => {
      toast.success('Xavfsizlik sozlamalari saqlandi');
      qc.invalidateQueries({ queryKey: ['security-settings'] });
    },
    onError: (e) => toast.error(getApiErrorMessage(e)),
  });

  const currentIp = data?.currentIp ?? '';
  const currentInList = currentIp ? ips.includes(currentIp) : true;

  return (
    <Card className="mt-6">
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <ShieldAlert className="h-5 w-5 text-primary" /> IP cheklash (allowlist)
        </CardTitle>
        <CardDescription>
          Yoqilganda — faqat ro&apos;yxatdagi IP manzillardan admin panelga kirish mumkin.
          Boshqa barcha IP&apos;lar cheklanadi.
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-5">
        {/* Joriy IP */}
        <div className="flex flex-wrap items-center justify-between gap-2 rounded-lg border border-border bg-muted/30 p-3">
          <span className="flex items-center gap-2 text-sm">
            <Globe className="h-4 w-4 text-muted-foreground" />
            Sizning IP manzilingiz:{' '}
            <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs font-semibold">
              {currentIp || '—'}
            </code>
          </span>
          {currentIp && !currentInList && (
            <Button size="sm" variant="outline" onClick={() => addIp(currentIp)}>
              <Plus className="h-3.5 w-3.5" /> Ro&apos;yxatga qo&apos;shish
            </Button>
          )}
        </div>

        {/* Enforcement toggle */}
        <div className="flex items-center justify-between rounded-lg border border-border p-4">
          <div className="space-y-0.5">
            <Label>IP cheklashni yoqish</Label>
            <p className="text-xs text-muted-foreground">
              Yoqilsa, faqat quyidagi IP&apos;lardan kirish mumkin bo&apos;ladi.
            </p>
          </div>
          <Switch checked={enabled} onCheckedChange={setEnabled} />
        </div>

        {/* IP ro'yxati */}
        <div className="space-y-2">
          <Label>Ruxsat etilgan IP&apos;lar</Label>
          <div className="flex gap-2">
            <Input
              value={ipInput}
              onChange={(e) => setIpInput(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') {
                  e.preventDefault();
                  addIp(ipInput);
                }
              }}
              placeholder="Masalan: 178.21.45.102"
            />
            <Button type="button" variant="outline" className="shrink-0" onClick={() => addIp(ipInput)}>
              <Plus className="h-4 w-4" /> Qo&apos;shish
            </Button>
          </div>
          {ips.length > 0 ? (
            <div className="flex flex-wrap gap-2 pt-1">
              {ips.map((ip) => (
                <Badge key={ip} variant="secondary" className="gap-1.5 pr-1.5 font-mono">
                  {ip}
                  <button
                    type="button"
                    onClick={() => setIps((prev) => prev.filter((x) => x !== ip))}
                    className="rounded-full p-0.5 hover:bg-foreground/10"
                    aria-label="O'chirish"
                  >
                    <X className="h-3 w-3" />
                  </button>
                </Badge>
              ))}
            </div>
          ) : (
            <p className="text-xs text-muted-foreground">
              IP qo&apos;shilmagan — cheklash yoqilsa ham hech kim bloklanmaydi.
            </p>
          )}
        </div>

        {enabled && currentIp && !currentInList && (
          <p className="flex items-center gap-1.5 rounded-lg bg-warning/10 p-3 text-xs text-warning">
            <ShieldAlert className="h-4 w-4 shrink-0" />
            Diqqat: joriy IP&apos;ingiz ro&apos;yxatda yo&apos;q. Saqlashdan oldin qo&apos;shing,
            aks holda o&apos;zingizni bloklab qo&apos;yasiz.
          </p>
        )}

        <div className="flex justify-end">
          <Button onClick={() => mutation.mutate()} loading={mutation.isPending}>
            O&apos;zgarishlarni saqlash
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}

function ChangePasswordCard() {
  const [current, setCurrent] = useState('');
  const [next, setNext] = useState('');
  const [confirm, setConfirm] = useState('');
  const [loading, setLoading] = useState(false);

  const submit = async () => {
    if (next !== confirm) {
      toast.error('Yangi parollar mos kelmaydi');
      return;
    }
    if (next.length < 8) {
      toast.error('Parol kamida 8 belgidan iborat bo\'lishi kerak');
      return;
    }
    setLoading(true);
    try {
      await authApi.changePassword(current, next);
      toast.success('Parol o\'zgartirildi');
      setCurrent(''); setNext(''); setConfirm('');
    } catch (err) {
      toast.error(getApiErrorMessage(err));
    } finally {
      setLoading(false);
    }
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Lock className="h-5 w-5 text-primary" /> Parolni o&apos;zgartirish
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="space-y-2">
          <Label htmlFor="current">Joriy parol</Label>
          <Input id="current" type="password" value={current} onChange={(e) => setCurrent(e.target.value)} placeholder="••••••••" />
        </div>
        <Separator />
        <div className="grid gap-4 sm:grid-cols-2">
          <div className="space-y-2">
            <Label htmlFor="next">Yangi parol</Label>
            <Input id="next" type="password" value={next} onChange={(e) => setNext(e.target.value)} placeholder="Kamida 8 belgi" />
          </div>
          <div className="space-y-2">
            <Label htmlFor="confirm">Tasdiqlash</Label>
            <Input id="confirm" type="password" value={confirm} onChange={(e) => setConfirm(e.target.value)} placeholder="Qaytaring" />
          </div>
        </div>
        <div className="flex justify-end">
          <Button onClick={submit} loading={loading} disabled={!current || !next || !confirm}>
            Saqlash
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}
