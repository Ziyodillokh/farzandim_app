'use client';

import { useEffect, useRef } from 'react';

import { normalizeReaderUid } from '@/data/schemas/cards';

/**
 * USB NFC o'qigich (klaviatura rejimi): karta tegizilganda o'qigich UID'ni juda tez "yozadi"
 * va odatda Enter bosadi. Shu oqim sahifa darajasida ushlanadi — kartaning raqami ochiq
 * maydonga tushib qolsa ham, Enter yutiladi va natija `onCard` ga boradi.
 * Odam bunchalik tez yoza olmaydi; shtrix-kod skaneri esa "P-1234" yozadi — u karta emas.
 */

/** Belgilar orasidagi eng katta oraliq (o'qigich ~5–30 ms; odam ketma-ket 8+ tugmani bunchalik tez bosa olmaydi). */
export const WEDGE_MAX_GAP_MS = 80;
/** Enter bo'lmasa — oxirgi belgidan keyin shuncha kutib, o'qish yakunlanadi. */
export const WEDGE_IDLE_MS = 150;

export type WedgeToken = { kind: 'char'; ch: string } | { kind: 'end' } | { kind: 'ignore' } | { kind: 'reset' };

const IGNORED_KEYS = new Set(['Shift', 'CapsLock', 'NumLock']);
const END_CODES = new Set(['Enter', 'NumpadEnter', 'Tab']);

/**
 * Tugma → belgi. `e.code` ishlatiladi: noutbukda rus/o'zbek klaviaturasi yoqilgan bo'lsa ham
 * o'qigichning "A–F" harflari to'g'ri olinadi.
 */
export function wedgeToken(e: Pick<KeyboardEvent, 'code' | 'key' | 'ctrlKey' | 'metaKey' | 'altKey'>): WedgeToken {
  if (e.ctrlKey || e.metaKey || e.altKey) return { kind: 'reset' };
  if (IGNORED_KEYS.has(e.key)) return { kind: 'ignore' };
  if (END_CODES.has(e.code) || e.key === 'Enter') return { kind: 'end' };
  const digit = /^(?:Digit|Numpad)(\d)$/.exec(e.code);
  if (digit) return { kind: 'char', ch: digit[1] };
  const letter = /^Key([A-F])$/.exec(e.code);
  if (letter) return { kind: 'char', ch: letter[1] };
  if (e.code === 'Minus' || e.code === 'NumpadSubtract' || e.code === 'Semicolon' || e.code === 'Space') return { kind: 'char', ch: ':' };
  return { kind: 'reset' };
}

/** Sof mantiq (vaqt tashqaridan): tugmalar oqimidan karta UID'sini ajratadi. */
export function createWedgeParser(onCard: (uid: string) => void) {
  let buffer = '';
  let lastAt = Number.NEGATIVE_INFINITY;

  const finish = (): boolean => {
    const uid = buffer ? normalizeReaderUid(buffer) : null;
    buffer = '';
    if (!uid) return false;
    onCard(uid);
    return true;
  };

  return {
    /** `true` — tugma karta o'qishini yakunladi (Enter/Tab yutilishi kerak). */
    key(token: WedgeToken, at: number): boolean {
      if (token.kind === 'ignore') return false;
      if (token.kind === 'reset') {
        buffer = '';
        return false;
      }
      const fast = at - lastAt <= WEDGE_MAX_GAP_MS;
      if (token.kind === 'end') return fast && finish();
      if (!fast) buffer = '';
      buffer += token.ch;
      lastAt = at;
      return false;
    },
    /** Enter'siz o'qigichlar uchun: oxirgi belgidan `WEDGE_IDLE_MS` o'tgach chaqiriladi. */
    idle(at: number): boolean {
      return at - lastAt >= WEDGE_IDLE_MS && finish();
    },
  };
}

/** Sahifa ochiq va oyna faol bo'lsa, USB o'qigichdan kelgan kartani `onCard` ga beradi. */
export function useCardWedge(onCard: (uid: string) => void, enabled = true) {
  const handler = useRef(onCard);
  handler.current = onCard;

  useEffect(() => {
    if (!enabled) return;
    const parser = createWedgeParser((uid) => handler.current(uid));
    let timer: ReturnType<typeof setTimeout> | undefined;
    const onKeyDown = (e: KeyboardEvent) => {
      if (parser.key(wedgeToken(e), performance.now())) {
        e.preventDefault();
        e.stopPropagation();
      }
      clearTimeout(timer);
      timer = setTimeout(() => parser.idle(performance.now()), WEDGE_IDLE_MS);
    };
    window.addEventListener('keydown', onKeyDown, true);
    return () => {
      window.removeEventListener('keydown', onKeyDown, true);
      clearTimeout(timer);
    };
  }, [enabled]);
}
