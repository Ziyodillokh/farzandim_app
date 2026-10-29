'use client';

import { useCallback, useSyncExternalStore } from 'react';

import type { Filters } from '@/data/contracts';
import { PERIODS } from '@/data/mock/model/calendar';
import { GENDERS, GRADE_BANDS, SCHOOL_TYPES } from '@/data/reference/domains';
import { readPref, writePref } from '@/lib/prefs';

/**
 * Global filtrlar (davr, sinf guruhi, jins, maktab turi) — barcha sahifalarda
 * bir xil; brauzerda saqlanadi.
 */
export const DEFAULT_FILTERS: Filters = { period: 'QUARTER', grades: 'ALL', gender: 'ALL', schoolType: 'ALL' };

const KEY = 'filters';
type Listener = () => void;
const listeners = new Set<Listener>();
let current: Filters | undefined;

function sanitize(raw: unknown): Filters {
  const v = (raw && typeof raw === 'object' ? raw : {}) as Record<string, unknown>;
  const pick = <T extends string>(value: unknown, allowed: readonly T[], fallback: T): T =>
    typeof value === 'string' && (allowed as readonly string[]).includes(value) ? (value as T) : fallback;
  return {
    period: pick(v.period, PERIODS, DEFAULT_FILTERS.period),
    grades: pick(v.grades, GRADE_BANDS, DEFAULT_FILTERS.grades),
    gender: pick(v.gender, GENDERS, DEFAULT_FILTERS.gender),
    schoolType: pick(v.schoolType, ['ALL', ...SCHOOL_TYPES] as const, DEFAULT_FILTERS.schoolType),
  };
}

export function getFilters(): Filters {
  if (current === undefined) current = sanitize(readPref(KEY));
  return current;
}

export function setFilters(patch: Partial<Filters>): void {
  current = sanitize({ ...getFilters(), ...patch });
  writePref(KEY, current);
  for (const l of listeners) l();
}

export function resetFilters(): void {
  setFilters(DEFAULT_FILTERS);
}

function subscribe(listener: Listener): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

const serverSnapshot = () => DEFAULT_FILTERS;

export function useFilters(): [Filters, (patch: Partial<Filters>) => void] {
  const filters = useSyncExternalStore(subscribe, getFilters, serverSnapshot);
  const update = useCallback((patch: Partial<Filters>) => setFilters(patch), []);
  return [filters, update];
}

export function isDefaultFilters(f: Filters): boolean {
  return f.grades === 'ALL' && f.gender === 'ALL' && f.schoolType === 'ALL';
}

// ───────────────────────── Doira (respublika foydalanuvchisi uchun hudud tanlovi) ─────────────────────────

const SCOPE_KEY = 'scopeRegion';
const scopeListeners = new Set<Listener>();
let scopeCurrent: string | undefined;

export function getScopeRegion(): string {
  if (scopeCurrent === undefined) {
    const raw = readPref<string>(SCOPE_KEY);
    scopeCurrent = typeof raw === 'string' && raw.length > 0 ? raw : 'ALL';
  }
  return scopeCurrent;
}

export function setScopeRegion(value: string): void {
  scopeCurrent = value;
  writePref(SCOPE_KEY, value);
  for (const l of scopeListeners) l();
}

function subscribeScope(listener: Listener): () => void {
  scopeListeners.add(listener);
  return () => scopeListeners.delete(listener);
}

const scopeServerSnapshot = () => 'ALL';

export function useScopeRegion(): [string, (value: string) => void] {
  const value = useSyncExternalStore(subscribeScope, getScopeRegion, scopeServerSnapshot);
  return [value, setScopeRegion];
}
