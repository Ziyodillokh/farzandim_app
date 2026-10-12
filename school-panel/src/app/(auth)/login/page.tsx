'use client';

import { ArrowRight, Eye, EyeOff, HeartHandshake, KeyRound, ScanLine, Smartphone } from 'lucide-react';
import { useRouter } from 'next/navigation';
import { useEffect, useState, type FormEvent } from 'react';

import { DEMO_ACCOUNTS, findDemoAccount } from '@/auth/demo-accounts';
import { getSession, setSession } from '@/auth/session';
import { SchoolLogo } from '@/components/common/school-logo';
import { ParvozLogo } from '@/components/layout/parvoz-logo';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { transact } from '@/data/mock/db';
import { useSchool } from '@/features/school/hooks';
import { useI18n, type Locale } from '@/i18n';
import { cn } from '@/lib/utils';

export default function LoginPage() {
  const { t, locale, setLocale } = useI18n();
  const router = useRouter();
  const { data } = useSchool();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState(false);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (getSession()) router.replace('/dashboard');
  }, [router]);

  const submit = (e: FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(false);
    // Kichik kechikish — haqiqiy so'rov hissi (va parol taxminiga to'siq).
    setTimeout(() => {
      const account = findDemoAccount(username, password);
      if (!account) {
        setError(true);
        setLoading(false);
        return;
      }
      transact((tables) => {
        const staff = tables.staff.find((s) => s.id === account.staffId);
        tables.audit.push({
          id: `aud-login-${Date.now()}`,
          at: new Date().toISOString(),
          actorId: account.staffId,
          actorName: staff?.fullName ?? account.username,
          module: 'AUTH',
          action: 'auth.login',
          entityId: null,
          summary: 'Panelga kirdi',
          before: null,
          after: null,
        });
      });
      setSession({ staffId: account.staffId, username: account.username, role: account.role, loggedInAt: new Date().toISOString() });
      router.replace('/dashboard');
    }, 450);
  };

  const features = [
    { icon: Smartphone, text: t('auth.heroPoints.schoolMode') },
    { icon: ScanLine, text: t('auth.heroPoints.attendance') },
    { icon: HeartHandshake, text: t('auth.heroPoints.care') },
  ];

  return (
    <div className="grid min-h-screen lg:grid-cols-[1.05fr_1fr]">
      <aside className="relative hidden overflow-hidden bg-hero-gradient p-12 text-white lg:flex lg:flex-col">
        <div className="pointer-events-none absolute -right-32 -top-32 h-96 w-96 rounded-full bg-primary/30 blur-3xl" />
        <div className="pointer-events-none absolute -bottom-40 -left-24 h-[28rem] w-[28rem] rounded-full bg-[#305399]/40 blur-3xl" />
        <div className="relative flex items-center gap-3">
          <ParvozLogo className="h-11 w-11 rounded-xl shadow-primary-glow" />
          <div>
            <p className="font-display text-lg font-semibold">Parvoz School</p>
            <p className="text-xs text-white/60">{t('common.tagline')}</p>
          </div>
        </div>

        <div className="relative my-auto max-w-xl py-12">
          <div className="mb-8 inline-flex items-center gap-3 rounded-2xl border border-white/10 bg-white/[0.06] p-3 pr-5 backdrop-blur">
            <SchoolLogo school={data?.school} className="h-12 w-12" />
            <div>
              <p className="font-semibold">{data?.school.name ?? '…'}</p>
              <p className="text-sm text-white/60">
                {data?.school.city} · {data?.school.academicYear}
              </p>
            </div>
          </div>
          <h1 className="font-display text-[2.1rem] font-semibold leading-tight">{t('auth.heroTitle')}</h1>
          <ul className="mt-8 space-y-4">
            {features.map(({ icon: Icon, text }) => (
              <li key={text} className="flex items-center gap-4">
                <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-primary/25 text-[#9CC0FF]">
                  <Icon className="h-5 w-5" />
                </span>
                <span className="text-white/85">{text}</span>
              </li>
            ))}
          </ul>
        </div>

        <p className="relative font-display text-sm tracking-wide text-white/50">PARVOZ — Himoyadan yuksalishgacha</p>
      </aside>

      <main className="flex flex-col bg-background">
        <div className="flex items-center justify-between p-6">
          <div className="flex items-center gap-2 lg:hidden">
            <ParvozLogo className="h-9 w-9 rounded-xl" />
            <span className="font-display font-semibold">Parvoz School</span>
          </div>
          <div className="ml-auto flex h-9 items-center rounded-lg border p-1">
            {(['uz', 'ru'] as Locale[]).map((l) => (
              <button
                key={l}
                type="button"
                onClick={() => setLocale(l)}
                className={cn(
                  'h-7 rounded-md px-2.5 text-xs font-semibold uppercase',
                  locale === l ? 'bg-primary text-primary-foreground' : 'text-muted-foreground hover:text-foreground',
                )}
              >
                {l}
              </button>
            ))}
          </div>
        </div>

        <div className="mx-auto flex w-full max-w-md flex-1 flex-col justify-center px-6 pb-12">
          <div className="animate-slide-up">
            <h2 className="font-display text-2xl font-semibold">{t('auth.title')}</h2>
            <p className="mt-2 text-sm text-muted-foreground">{t('auth.subtitle')}</p>

            <form onSubmit={submit} className="mt-8 space-y-4" noValidate>
              <div className="space-y-2">
                <Label htmlFor="username">{t('auth.username')}</Label>
                <Input
                  id="username"
                  autoComplete="username"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  placeholder={t('auth.usernamePlaceholder')}
                  className="h-11"
                  autoFocus
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="password">{t('auth.password')}</Label>
                <div className="relative">
                  <Input
                    id="password"
                    type={showPassword ? 'text' : 'password'}
                    autoComplete="current-password"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder={t('auth.passwordPlaceholder')}
                    className="h-11 pr-11"
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword((s) => !s)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
                    aria-label={t('auth.password')}
                  >
                    {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                  </button>
                </div>
              </div>
              {error && (
                <p role="alert" className="rounded-lg bg-destructive/10 px-3 py-2 text-sm font-medium text-destructive">
                  {t('auth.invalid')}
                </p>
              )}
              <Button type="submit" size="lg" className="w-full" loading={loading} disabled={!username || !password}>
                {t('auth.submit')}
                {!loading && <ArrowRight />}
              </Button>
            </form>

            <div className="mt-10 rounded-2xl border bg-card p-4">
              <div className="flex items-center gap-2">
                <KeyRound className="h-4 w-4 text-primary" />
                <p className="text-sm font-semibold">{t('auth.demoAccounts')}</p>
              </div>
              <p className="mt-1 text-xs text-muted-foreground">{t('auth.demoAccountsHint')}</p>
              <div className="mt-3 grid gap-1.5">
                {DEMO_ACCOUNTS.map((account) => (
                  <button
                    key={account.username}
                    type="button"
                    onClick={() => {
                      setUsername(account.username);
                      setPassword(account.password);
                      setError(false);
                    }}
                    className={cn(
                      'flex items-center justify-between rounded-lg border px-3 py-2 text-left text-sm transition-colors hover:border-primary/50 hover:bg-primary/5',
                      username === account.username && 'border-primary bg-primary/5',
                    )}
                  >
                    <span className="font-medium">{t(`enums.role.${account.role}`)}</span>
                    <span className="font-mono text-xs text-muted-foreground">
                      {account.username} / {account.password}
                    </span>
                  </button>
                ))}
              </div>
            </div>
            <p className="mt-6 text-center text-xs text-muted-foreground">{t('demo.bannerText')}</p>
          </div>
        </div>
      </main>
    </div>
  );
}
