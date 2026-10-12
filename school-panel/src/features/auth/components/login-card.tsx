'use client';

import { Eye, EyeOff, Lock, UserRound } from 'lucide-react';
import { useState, type FormEvent } from 'react';

import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { useI18n } from '@/i18n';
import { useLogin } from '../use-login';
import { DemoAccountGrid } from './demo-account-grid';

/** Shisha login kartasi: forma + demo hisoblar (bir bosishda kirish). */
export function LoginCard() {
  const { t } = useI18n();
  const { login, loading, pendingUser, error, clearError } = useLogin();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [viaCard, setViaCard] = useState(false);

  const submit = (e: FormEvent) => {
    e.preventDefault();
    setViaCard(false);
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
              aria-label={t('auth.password')}
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
        <Button type="submit" size="lg" className="w-full" loading={loading && !viaCard} disabled={!username || !password || loading}>
          {t('auth.submit')}
        </Button>
      </form>

      <div className="my-5 flex items-center gap-3 text-[0.72rem] text-muted-foreground">
        <span className="h-px flex-1 bg-white/10" />
        {t('auth.oneClick')}
        <span className="h-px flex-1 bg-white/10" />
      </div>
      <DemoAccountGrid
        pendingUser={pendingUser}
        disabled={loading}
        onPick={(a) => {
          setUsername(a.username);
          setPassword(a.password);
          setViaCard(true);
          login(a.username, a.password);
        }}
      />
      <p className="mt-4 text-center text-[0.7rem] text-muted-foreground">{t('common.demoBadge')}</p>
    </div>
  );
}
