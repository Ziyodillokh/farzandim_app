'use client';

import { ArrowRight, Eye, EyeOff, Landmark, Lock, MapPin, UserRound } from 'lucide-react';
import { useState, type FormEvent } from 'react';

import { DEMO_ACCOUNTS } from '@/auth/demo-accounts';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { regionName } from '@/data/reference/regions';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { useLogin } from '../use-login';

/** Shisha login kartasi: forma + demo hisoblar (bir bosishda kirish). */
export function LoginCard() {
  const { t, locale } = useI18n();
  const { login, loading, pendingUser, error, clearError } = useLogin();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);

  const submit = (e: FormEvent) => {
    e.preventDefault();
    login(username, password);
  };

  return (
    <div className="glass-strong w-full rounded-3xl p-6 sm:p-7 animate-slide-up">
      <h1 className="font-display text-[1.45rem] font-semibold tracking-[-0.02em] text-white">{t('auth.title')}</h1>
      <p className="mt-1.5 text-sm text-muted-foreground">{t('auth.subtitle')}</p>

      <form onSubmit={submit} className="mt-6 space-y-4">
        <div className="space-y-1.5">
          <Label htmlFor="username">{t('auth.username')}</Label>
          <Input
            id="username"
            autoComplete="username"
            icon={<UserRound />}
            className="h-11"
            placeholder={t('auth.usernamePlaceholder')}
            value={username}
            onChange={(e) => {
              setUsername(e.target.value);
              clearError();
            }}
          />
        </div>
        <div className="space-y-1.5">
          <Label htmlFor="password">{t('auth.password')}</Label>
          <div className="relative">
            <Input
              id="password"
              type={showPassword ? 'text' : 'password'}
              autoComplete="current-password"
              icon={<Lock />}
              className="h-11 pr-11"
              placeholder={t('auth.passwordPlaceholder')}
              value={password}
              onChange={(e) => {
                setPassword(e.target.value);
                clearError();
              }}
            />
            <button
              type="button"
              onClick={() => setShowPassword((v) => !v)}
              className="absolute right-2 top-1/2 flex h-8 w-8 -translate-y-1/2 items-center justify-center rounded-lg text-muted-foreground hover:bg-white/[0.06] hover:text-foreground"
              aria-label={showPassword ? t('auth.hidePassword') : t('auth.showPassword')}
            >
              {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
            </button>
          </div>
        </div>
        {error && (
          <p role="alert" className="rounded-xl bg-destructive/15 px-3 py-2 text-sm font-medium text-red-300 ring-1 ring-inset ring-destructive/30">
            {t('auth.invalid')}
          </p>
        )}
        <Button type="submit" size="lg" className="w-full" loading={loading && pendingUser === username} disabled={!username || !password || loading}>
          {t('auth.submit')}
        </Button>
      </form>

      <div className="mt-6">
        <p className="mb-2.5 text-2xs font-semibold uppercase tracking-[0.14em] text-muted-foreground">{t('auth.oneClick')}</p>
        <ul className="space-y-2">
          {DEMO_ACCOUNTS.map((a) => {
            const Icon = a.role === 'NATIONAL' ? Landmark : MapPin;
            const title = a.regionId ? t('auth.accounts.REGIONAL', { region: regionName(a.regionId, locale, true) }) : t('auth.accounts.NATIONAL');
            return (
              <li key={a.username}>
                <button
                  type="button"
                  disabled={loading}
                  onClick={() => {
                    setUsername(a.username);
                    setPassword(a.password);
                    login(a.username, a.password);
                  }}
                  className={cn(
                    'group flex w-full items-center gap-3 rounded-2xl bg-white/[0.04] px-3 py-2.5 text-left ring-1 ring-inset ring-white/[0.08] transition-all hover:bg-white/[0.08] hover:ring-brand-400/40 disabled:opacity-60',
                    pendingUser === a.username && 'ring-brand-400/60',
                  )}
                >
                  <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-brand-500/50 to-cyan-400/25 text-brand-100 ring-1 ring-inset ring-white/10">
                    <Icon className="h-5 w-5" />
                  </span>
                  <span className="min-w-0 flex-1 leading-tight">
                    <span className="block truncate text-sm font-semibold text-white">{title}</span>
                    <span className="mt-0.5 block truncate font-mono text-[0.72rem] text-muted-foreground">
                      {a.username} · {a.password}
                    </span>
                  </span>
                  <ArrowRight className="h-4 w-4 text-muted-foreground transition-transform group-hover:translate-x-0.5 group-hover:text-white" />
                </button>
              </li>
            );
          })}
        </ul>
      </div>
    </div>
  );
}
