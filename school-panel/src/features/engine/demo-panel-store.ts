'use client';

import { useSyncExternalStore } from 'react';

/**
 * Demo panel ochiq/yopiq — topbar tugmasi, Ctrl + Shift + D va sozlamalar
 * kartochkasi bitta holatdan foydalanadi.
 */
type Listener = () => void;
const listeners = new Set<Listener>();
let open = false;

export function setDemoPanelOpen(next: boolean): void {
  if (next === open) return;
  open = next;
  for (const l of listeners) l();
}

export function toggleDemoPanel(): void {
  setDemoPanelOpen(!open);
}

function subscribe(listener: Listener): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

function getOpen(): boolean {
  return open;
}

export function useDemoPanelOpen(): boolean {
  return useSyncExternalStore(subscribe, getOpen, () => false);
}
