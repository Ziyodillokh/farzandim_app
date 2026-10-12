'use client';

import { useRouter } from 'next/navigation';
import { useEffect } from 'react';

import { FullScreenLoader } from '@/auth/guards';
import { getSession } from '@/auth/session';

/** `/school/` — kirgan bo'lsa bosh sahifa, aks holda login. */
export default function Home() {
  const router = useRouter();
  useEffect(() => {
    router.replace(getSession() ? '/dashboard' : '/login');
  }, [router]);
  return <FullScreenLoader />;
}
