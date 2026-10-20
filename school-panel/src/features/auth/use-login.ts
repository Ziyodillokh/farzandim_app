'use client';

import { useRouter } from 'next/navigation';
import { useCallback, useState } from 'react';

import { findDemoAccount } from '@/auth/demo-accounts';
import { signIn } from '@/auth/sign-in';
import { httpSignIn, LoginError, type LoginErrorCode } from '@/data/http/session';
import { isHttpMode } from '@/data/source';

/** Kichik kechikish — haqiqiy so'rov hissi (va parol taxminiga to'siq). */
const LOGIN_DELAY_MS = 450;

export type LoginFailure = { code: LoginErrorCode; retryAfterSeconds?: number };

/**
 * Kirish: demo rejimda — demo hisoblar; http rejimda — backend (maktab kodi +
 * login + parol, kerak bo'lsa 2FA kodi). Muvaffaqiyatda bosh sahifaga o'tadi.
 */
export function useLogin() {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [pendingUser, setPendingUser] = useState<string | null>(null);
  const [failure, setFailure] = useState<LoginFailure | null>(null);

  const login = useCallback(
    (username: string, password: string, extra: { school?: string; totp?: string } = {}) => {
      setLoading(true);
      setPendingUser(username);
      setFailure(null);
      if (isHttpMode) {
        httpSignIn({ school: extra.school ?? '', username, password, ...(extra.totp && { totp: extra.totp }) })
          .then(() => router.replace('/dashboard'))
          .catch((e: unknown) => {
            setFailure(
              e instanceof LoginError ? { code: e.code, retryAfterSeconds: e.retryAfterSeconds } : { code: 'NETWORK' },
            );
            setLoading(false);
            setPendingUser(null);
          });
        return;
      }
      setTimeout(() => {
        const account = findDemoAccount(username, password);
        if (!account) {
          setFailure({ code: 'INVALID_CREDENTIALS' });
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

  return {
    login,
    loading,
    pendingUser,
    failure,
    /** Eski API: oddiy "noto'g'ri login" xatosi. */
    error: failure?.code === 'INVALID_CREDENTIALS',
    clearError: () => setFailure(null),
  };
}
