'use client';

import { useRouter } from 'next/navigation';
import { useCallback, useState } from 'react';

import { findDemoAccount } from '@/auth/demo-accounts';
import { signIn } from '@/auth/sign-in';

/** Kichik kechikish — haqiqiy so'rov hissi (va parol taxminiga to'siq). */
const LOGIN_DELAY_MS = 450;

/** Demo kirish: hisobni tekshiradi, umumiy sessiya bilan kiradi va bosh sahifaga o'tadi. */
export function useLogin() {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [pendingUser, setPendingUser] = useState<string | null>(null);
  const [error, setError] = useState(false);

  const login = useCallback(
    (username: string, password: string) => {
      setLoading(true);
      setPendingUser(username);
      setError(false);
      setTimeout(() => {
        const account = findDemoAccount(username, password);
        if (!account) {
          setError(true);
          setLoading(false);
          setPendingUser(null);
          return;
        }
        signIn(account, 'shared');
        router.replace('/dashboard');
      }, LOGIN_DELAY_MS);
    },
    [router],
  );

  return { login, loading, pendingUser, error, clearError: () => setError(false) };
}
