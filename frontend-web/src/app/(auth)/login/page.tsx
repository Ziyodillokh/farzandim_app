'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import Image from 'next/image';
import Link from 'next/link';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { useAuthStore } from '@/stores/auth.store';
import { api } from '@/lib/api/client';
import { toast } from 'sonner';
import type { AuthTokens, User } from '@/types/api.types';

/**
 * Login screen — Flutter `telegram_login_screen.dart` web ekvivalenti.
 *
 * Production'da: Telegram Login Widget script embed qilinadi.
 * Development'da: Dev login (faqat dev mode) — backend /auth/dev-login.
 *
 * Web Telegram Login Widget kiritish:
 *   <script async src="https://telegram.org/js/telegram-widget.js?22"
 *           data-telegram-login="{BOT_USERNAME}"
 *           data-size="large" data-onauth="onTelegramAuth(user)"></script>
 */
export default function LoginPage() {
  const router = useRouter();
  const setAuth = useAuthStore((s) => s.setAuth);
  const [loading, setLoading] = useState(false);
  const [devMode, setDevMode] = useState(false);
  const [phone, setPhone] = useState('+998');

  const handleDevLogin = async () => {
    setLoading(true);
    try {
      // Dev-only: simulated Telegram auth payload (backend test mode)
      const res = await api.post<AuthTokens & { user: User }>('/auth/telegram', {
        id: Date.now(),
        first_name: 'Dev',
        last_name: 'User',
        username: 'devuser',
        auth_date: Math.floor(Date.now() / 1000),
        hash: 'dev-mode-skip-verification',
      });
      setAuth(res.user, res.accessToken, res.refreshToken);
      toast.success('Muvaffaqiyatli kirildi');
      router.push('/dashboard');
    } catch (err) {
      const msg = err instanceof Error ? err.message : "Kirish muvaffaqiyatsiz";
      toast.error(msg);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="container flex min-h-screen items-center justify-center py-12">
      <Card className="w-full max-w-md">
        <CardHeader className="text-center">
          <div className="mx-auto mb-4">
            <Image
              src="/assets/app_icon/parent_app_icon_white.png"
              alt="Farzandim"
              width={80}
              height={80}
              className="object-contain"
            />
          </div>
          <CardTitle className="text-2xl">Tizimga kirish</CardTitle>
          <CardDescription>Farzandim — ota-ona dashboard</CardDescription>
        </CardHeader>

        <CardContent className="flex flex-col gap-4">
          {/* Telegram Login Widget — script tag production'da */}
          <Button size="lg" className="w-full" disabled>
            <svg className="h-5 w-5" viewBox="0 0 24 24" fill="currentColor">
              <path d="M12 0C5.373 0 0 5.373 0 12s5.373 12 12 12 12-5.373 12-12S18.627 0 12 0zm5.894 8.221l-1.97 9.28c-.145.658-.537.818-1.084.508l-3-2.21-1.446 1.394c-.14.18-.357.295-.6.295l.213-3.053 5.56-5.022c.24-.213-.054-.334-.373-.121l-6.869 4.326-2.96-.924c-.64-.203-.658-.64.135-.954l11.566-4.458c.538-.196 1.006.128.832.941z" />
            </svg>
            Telegram orqali kirish
          </Button>
          <p className="text-center text-xs text-muted-foreground">
            (Telegram Bot Token .env'da test bo'lganda yoqiladi)
          </p>

          <div className="relative my-2">
            <div className="absolute inset-0 flex items-center">
              <span className="w-full border-t border-border" />
            </div>
            <div className="relative flex justify-center text-xs uppercase">
              <span className="bg-card px-2 text-muted-foreground">yoki</span>
            </div>
          </div>

          {/* Dev mode (test only) */}
          {!devMode ? (
            <Button variant="outline" size="lg" onClick={() => setDevMode(true)}>
              Dev test kirish (backend test)
            </Button>
          ) : (
            <div className="flex flex-col gap-3">
              <Input
                placeholder="+998 90 123 45 67"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
              />
              <Button size="lg" onClick={handleDevLogin} disabled={loading}>
                {loading ? 'Kirilmoqda…' : 'Kirish'}
              </Button>
            </div>
          )}

          <p className="mt-4 text-center text-sm text-muted-foreground">
            <Link href="/" className="hover:text-foreground hover:underline">
              ← Bosh sahifaga
            </Link>
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
