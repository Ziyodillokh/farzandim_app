'use client';

import { useRouter } from 'next/navigation';
import { useCallback, useState } from 'react';

import { findDemoAccount } from '@/auth/demo-accounts';
import { setSession } from '@/auth/session';
import { toLocalIso } from '@/data/mock/calendar';
import { clockNow } from '@/data/mock/clock';
import { transact } from '@/data/mock/db';

/** Kichik kechikish — haqiqiy so'rov hissi (va parol taxminiga to'siq). */
const LOGIN_DELAY_MS = 450;

/** Demo kirish: hisobni tekshiradi, auditga yozadi, sessiyani o'rnatadi va bosh sahifaga o'tadi. */
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
        transact((tables) => {
          const staff = tables.staff.find((s) => s.id === account.staffId);
          tables.audit.push({
            id: `aud-login-${Date.now()}`,
            at: toLocalIso(clockNow()),
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
      }, LOGIN_DELAY_MS);
    },
    [router],
  );

  return { login, loading, pendingUser, error, clearError: () => setError(false) };
}
