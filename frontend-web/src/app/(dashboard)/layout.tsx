'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useAuthStore } from '@/stores/auth.store';

/**
 * Protected layout — auth bo'lmagan foydalanuvchini /login'ga yo'naltiradi.
 */
export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const isAuthenticated = useAuthStore((s) => s.isAuthenticated);

  // DEV: auth bypass for preview (production'da olib tashlanadi)
  const DEV_BYPASS = process.env.NEXT_PUBLIC_DEV_AUTH_BYPASS === 'true';

  useEffect(() => {
    if (!isAuthenticated && !DEV_BYPASS) {
      router.replace('/login');
    }
  }, [isAuthenticated, router, DEV_BYPASS]);

  if (!isAuthenticated && !DEV_BYPASS) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <div className="text-muted-foreground">Yuklanmoqda…</div>
      </div>
    );
  }

  return <div className="min-h-screen bg-background">{children}</div>;
}
