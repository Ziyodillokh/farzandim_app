'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { Mail, Lock, ArrowRight, Shield, Sparkles } from 'lucide-react';
import { toast } from 'sonner';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { authApi } from '@/lib/api/admin.api';
import { useAuthStore } from '@/stores/auth.store';
import { getApiErrorMessage } from '@/lib/api/client';

const loginSchema = z.object({
  email: z.string().email("Email noto'g'ri"),
  password: z.string().min(1, 'Parolni kiriting'),
});
type LoginForm = z.infer<typeof loginSchema>;

export default function LoginPage() {
  const router = useRouter();
  const setAuth = useAuthStore((s) => s.setAuth);
  const setUser = useAuthStore((s) => s.setUser);
  const [loading, setLoading] = useState(false);
  const [twoFa, setTwoFa] = useState<{ challengeId: string; email: string } | null>(null);

  const {
    register,
    handleSubmit,
    formState: { errors },
    getValues,
  } = useForm<LoginForm>({
    resolver: zodResolver(loginSchema),
    defaultValues: { email: '', password: '' },
  });

  const onLogin = async (values: LoginForm) => {
    setLoading(true);
    try {
      const res = await authApi.login(values.email, values.password);
      if (res.requires2fa && res.challengeId) {
        setTwoFa({ challengeId: res.challengeId, email: values.email });
        toast.info('2FA kodi talab qilinmoqda');
        return;
      }
      const access = res.access_token ?? res.accessToken ?? '';
      const refresh = res.refresh_token ?? res.refreshToken ?? '';
      if (res.user) {
        setAuth(res.user, access, refresh);
      } else {
        setAuth({ id: '', email: values.email, name: 'Admin', phone: null, role: 'admin', moderatorRoleKey: 'admin', permissions: [], isFullAccess: false, status: 'active', lastActivityAt: null, twoFactorEnabled: false }, access, refresh);
        try { const me = await authApi.me(); setUser(me); } catch {}
      }
      toast.success('Tizimga muvaffaqiyatli kirildi');
      router.replace('/dashboard');
    } catch (err) {
      toast.error(getApiErrorMessage(err));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="relative flex min-h-screen items-center justify-center bg-hero-gradient px-4 py-12">
      {/* Decorative blobs */}
      <div className="absolute inset-0 overflow-hidden">
        <div className="absolute -left-32 -top-32 h-96 w-96 rounded-full bg-primary/10 blur-3xl" />
        <div className="absolute -bottom-32 -right-32 h-96 w-96 rounded-full bg-primary-glow/10 blur-3xl" />
      </div>

      <div className="relative w-full max-w-md">
        {/* Brand */}
        <div className="mb-8 flex flex-col items-center gap-3 text-center">
          <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-gradient-to-br from-primary to-primary-glow shadow-primary-glow">
            <span className="text-2xl font-bold text-primary-foreground">F</span>
          </div>
          <div>
            <h1 className="text-2xl font-bold tracking-tight">Farzandim Admin</h1>
            <p className="mt-1 text-sm text-muted-foreground">
              Boshqaruv panelingizga xush kelibsiz
            </p>
          </div>
        </div>

        <Card className="overflow-hidden shadow-soft-xl">
          {twoFa ? (
            <TwoFactorStep
              challengeId={twoFa.challengeId}
              email={twoFa.email}
              onCancel={() => setTwoFa(null)}
              onSuccess={(access, refresh, user) => {
                setAuth(user, access, refresh);
                toast.success('Tasdiqlandi');
                router.replace('/dashboard');
              }}
            />
          ) : (
            <form onSubmit={handleSubmit(onLogin)} className="flex flex-col gap-4 p-6">
              <div className="flex items-center gap-2 rounded-lg bg-primary-soft/60 p-3 text-sm text-foreground">
                <Sparkles className="h-4 w-4 shrink-0 text-primary" />
                <span>
                  Test: <code className="font-mono text-xs">admin@farzandim.uz / Admin12345</code>
                </span>
              </div>

              <div className="space-y-2">
                <Label htmlFor="email">Email</Label>
                <Input
                  id="email"
                  type="email"
                  placeholder="admin@farzandim.uz"
                  icon={<Mail />}
                  autoComplete="email"
                  {...register('email')}
                />
                {errors.email && <p className="text-xs text-destructive">{errors.email.message}</p>}
              </div>

              <div className="space-y-2">
                <Label htmlFor="password">Parol</Label>
                <Input
                  id="password"
                  type="password"
                  placeholder="••••••••"
                  icon={<Lock />}
                  autoComplete="current-password"
                  {...register('password')}
                />
                {errors.password && <p className="text-xs text-destructive">{errors.password.message}</p>}
              </div>

              <Button type="submit" size="lg" loading={loading} className="mt-2 w-full">
                Kirish
                <ArrowRight className="h-4 w-4" />
              </Button>
            </form>
          )}
        </Card>

        <p className="mt-6 text-center text-xs text-muted-foreground">
          © 2026 Farzandim. Maxfiy admin panel.
        </p>
      </div>
    </div>
  );
}

/* ─── 2FA step ─── */

function TwoFactorStep({
  challengeId,
  email,
  onSuccess,
  onCancel,
}: {
  challengeId: string;
  email: string;
  onSuccess: (access: string, refresh: string, user: import('@/types/api.types').AdminUser) => void;
  onCancel: () => void;
}) {
  const [code, setCode] = useState('');
  const [loading, setLoading] = useState(false);

  const submit = async () => {
    if (code.length !== 6) {
      toast.error('6 raqamli kodni kiriting');
      return;
    }
    setLoading(true);
    try {
      const res = await authApi.verify2fa(challengeId, code);
      const access = res.access_token ?? res.accessToken;
      const refresh = res.refresh_token ?? res.refreshToken ?? '';
      onSuccess(access, refresh, res.user);
    } catch (err) {
      toast.error(getApiErrorMessage(err));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex flex-col gap-4 p-6">
      <div className="flex items-center gap-3 rounded-lg bg-primary-soft p-3">
        <Shield className="h-5 w-5 text-primary" />
        <div className="flex-1">
          <p className="text-sm font-semibold">Ikki bosqichli tasdiqlash</p>
          <p className="text-xs text-muted-foreground">{email} uchun kod kiriting</p>
        </div>
      </div>

      <div className="space-y-2">
        <Label htmlFor="otp">6 raqamli kod</Label>
        <Input
          id="otp"
          type="text"
          inputMode="numeric"
          maxLength={6}
          value={code}
          onChange={(e) => setCode(e.target.value.replace(/\D/g, '').slice(0, 6))}
          placeholder="000000"
          className="text-center font-mono text-xl tracking-[0.5em]"
          autoFocus
        />
        <p className="text-xs text-muted-foreground">
          Authenticator ilovangizdan kodni kiriting yoki backup koddan foydalaning
        </p>
      </div>

      <div className="flex gap-2">
        <Button variant="outline" onClick={onCancel} className="flex-1">
          Orqaga
        </Button>
        <Button onClick={submit} loading={loading} className="flex-1">
          Tasdiqlash
        </Button>
      </div>
    </div>
  );
}
