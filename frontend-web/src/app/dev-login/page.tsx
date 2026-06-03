'use client';

import { Suspense, useEffect } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { useAuthStore } from '@/stores/auth.store';

/**
 * Dev login — JWT tokens'ni query string'dan oladi va auth store'ga saqlaydi.
 * Faqat development uchun. URL:
 *   /dev-login?token=...&refresh=...&userId=...&name=...&role=PARENT
 */
function DevLoginInner() {
  const router = useRouter();
  const params = useSearchParams();
  const setAuth = useAuthStore((s) => s.setAuth);

  useEffect(() => {
    const accessToken = params.get('token');
    const refreshToken = params.get('refresh');
    const userId = params.get('userId');
    const name = params.get('name') || 'Test User';
    const role = (params.get('role') || 'PARENT') as 'PARENT' | 'CHILD';
    const next = params.get('next') || '/dashboard';

    if (accessToken && refreshToken && userId) {
      setAuth(
        {
          id: userId,
          name,
          phone: null,
          role,
          avatarUrl: null,
          telegramId: null,
          language: 'uz',
        },
        accessToken,
        refreshToken,
      );
      router.replace(next);
    }
  }, [params, router, setAuth]);

  return (
    <div className="flex min-h-screen items-center justify-center text-muted-foreground">
      Login qilinmoqda…
    </div>
  );
}

export default function DevLoginPage() {
  return (
    <Suspense
      fallback={
        <div className="flex min-h-screen items-center justify-center text-muted-foreground">
          Yuklanmoqda…
        </div>
      }
    >
      <DevLoginInner />
    </Suspense>
  );
}
