'use client';

import { useCallback, useSyncExternalStore } from 'react';

import { roleHas, type Permission } from './permissions';
import { getSession, type Session, subscribeSession } from './session';

export function useSession(): Session | null {
  return useSyncExternalStore(subscribeSession, getSession, () => null);
}

/** `useCan()('attendance.mark')` — rolda ruxsat bormi. */
export function useCan(): (permission: Permission) => boolean {
  const session = useSession();
  return useCallback((permission: Permission) => Boolean(session && roleHas(session.role, permission)), [session]);
}
