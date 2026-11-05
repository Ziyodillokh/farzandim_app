'use client';

import { useRouter } from 'next/navigation';
import { useCallback, useEffect, useState } from 'react';

import { BASE_PATH } from '@/lib/base-path';

/**
 * Ichki havola (anchor) bosilganda marshrutchi (router) yo'li: `basePath` olib tashlanadi.
 * Boshqa origin, `_blank`, yuklab olish va joriy sahifaning o'zi/`#hash` — `null` (aralashmaymiz).
 */
export function internalRoute(
  anchor: { href: string; target?: string; hasDownload?: boolean },
  current: { href: string },
  basePath: string = BASE_PATH,
): string | null {
  if (anchor.hasDownload || (anchor.target && anchor.target !== '_self')) return null;
  let target: URL;
  let here: URL;
  try {
    target = new URL(anchor.href, current.href);
    here = new URL(current.href);
  } catch {
    return null;
  }
  if (target.origin !== here.origin) return null;
  if (target.pathname === here.pathname && target.search === here.search) return null;
  const path = basePath && target.pathname.startsWith(basePath) ? target.pathname.slice(basePath.length) || '/' : target.pathname;
  return `${path}${target.search}${target.hash}`;
}

/**
 * Saqlanmagan o'zgarishlar himoyasi: brauzer yorlig'ini yopish/yangilash (`beforeunload`) va
 * ilova ichidagi havolalar (menyu). Havola bosilsa o'tish to'xtatiladi — `pendingRoute` to'ladi,
 * UI tasdiq oynasini ko'rsatadi; `proceed()` o'tkazadi, `stay()` bekor qiladi.
 * Brauzerning "orqaga" tugmasi App Router'da ushlanmaydi (faqat `beforeunload`).
 */
export function useUnsavedChangesGuard(isDirty: boolean) {
  const router = useRouter();
  const [pendingRoute, setPendingRoute] = useState<string | null>(null);

  useEffect(() => {
    if (!isDirty) return;
    const onBeforeUnload = (event: BeforeUnloadEvent) => {
      event.preventDefault();
      event.returnValue = '';
    };
    const onClick = (event: MouseEvent) => {
      if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
      const anchor = event.target instanceof Element ? event.target.closest('a[href]') : null;
      if (!(anchor instanceof HTMLAnchorElement)) return;
      const route = internalRoute(
        { href: anchor.href, target: anchor.target, hasDownload: anchor.hasAttribute('download') },
        { href: window.location.href },
      );
      if (!route) return;
      event.preventDefault();
      event.stopPropagation();
      setPendingRoute(route);
    };
    window.addEventListener('beforeunload', onBeforeUnload);
    // Capture bosqichi: Next <Link> o'z onClick'idan oldin to'xtatiladi.
    document.addEventListener('click', onClick, true);
    return () => {
      window.removeEventListener('beforeunload', onBeforeUnload);
      document.removeEventListener('click', onClick, true);
    };
  }, [isDirty]);

  const proceed = useCallback(() => {
    if (pendingRoute) router.push(pendingRoute);
    setPendingRoute(null);
  }, [pendingRoute, router]);
  const stay = useCallback(() => setPendingRoute(null), []);

  return { pendingRoute, proceed, stay };
}
