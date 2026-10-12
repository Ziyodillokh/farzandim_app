'use client';

import type { ReactNode } from 'react';

import type { Permission } from './permissions';
import { useCan } from './use-session';

/** Ruxsat bo'lsa ko'rsatadi (tugmalar, bo'limlar). Servis baribir qayta tekshiradi. */
export function Can({ perm, children, fallback = null }: { perm: Permission; children: ReactNode; fallback?: ReactNode }) {
  const can = useCan();
  return <>{can(perm) ? children : fallback}</>;
}
