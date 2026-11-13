'use client';

import { useCallback, useEffect, useRef, useState } from 'react';

/**
 * Web NFC (Android uchun Chrome 89+): faqat NDEF o'qiladi; ekran o'chsa yoki sahifa yashirilsa
 * to'xtaydi; `scan()` foydalanuvchi tugmani bosganda chaqiriladi (brauzer talabi).
 */
type NdefRecord = { recordType: string; encoding?: string | null; data?: DataView | null };
type NdefReadingEvent = Event & { serialNumber: string; message: { records: readonly NdefRecord[] } };
type NdefReader = {
  scan(options?: { signal?: AbortSignal }): Promise<void>;
  onreading: ((event: NdefReadingEvent) => void) | null;
  onreadingerror: ((event: Event) => void) | null;
};
type NdefReaderCtor = new () => NdefReader;

/** O'qilgan karta: chip seriya raqami va (bo'lsa) kartadagi NDEF manzil. */
export type CardRead = { uid?: string; url?: string };
export type NfcState = 'unsupported' | 'idle' | 'starting' | 'scanning' | 'denied' | 'error';

/** Karta o'qigichda ushlab turilsa, shu oraliqda qayta hisoblanmaydi. */
export const REPEAT_IGNORE_MS = 2_500;

function readerCtor(): NdefReaderCtor | null {
  if (typeof window === 'undefined') return null;
  return (window as unknown as { NDEFReader?: NdefReaderCtor }).NDEFReader ?? null;
}

export const nfcSupported = () => readerCtor() !== null;

/** NDEF yozuvlaridan karta ma'lumoti: seriya raqami va birinchi URL yozuvi. */
export function cardReadFrom(serialNumber: string, records: readonly NdefRecord[]): CardRead {
  const urlRecord = records.find((r) => r.recordType === 'url' || r.recordType === 'absolute-url');
  let url: string | undefined;
  if (urlRecord?.data) {
    try {
      url = new TextDecoder(urlRecord.encoding || 'utf-8').decode(urlRecord.data);
    } catch {
      url = undefined;
    }
  }
  return { ...(serialNumber && { uid: serialNumber }), ...(url && { url }) };
}

/** Bir karta uzoq ushlab turilganda takror o'qishni o'tkazib yuborish. */
export function createRepeatFilter(windowMs = REPEAT_IGNORE_MS) {
  let last = { key: '', at: 0 };
  return (read: CardRead, now: number): boolean => {
    const key = read.uid ?? read.url ?? '';
    if (key && key === last.key && now - last.at < windowMs) return false;
    last = { key, at: now };
    return true;
  };
}

/** Web NFC o'qish: `start()` — tugma bosilganda; har o'qilgan karta `onRead` ga. */
export function useNfcReader(onRead: (read: CardRead) => void) {
  const [state, setState] = useState<NfcState>('idle');
  const controller = useRef<AbortController | null>(null);
  const handler = useRef(onRead);
  handler.current = onRead;

  useEffect(() => {
    if (!nfcSupported()) setState('unsupported');
    return () => controller.current?.abort();
  }, []);

  const start = useCallback(async () => {
    const Reader = readerCtor();
    if (!Reader) {
      setState('unsupported');
      return;
    }
    controller.current?.abort();
    const abort = new AbortController();
    controller.current = abort;
    const fresh = createRepeatFilter();
    setState('starting');
    try {
      const reader = new Reader();
      reader.onreading = (event) => {
        const read = cardReadFrom(event.serialNumber, event.message.records);
        if (fresh(read, Date.now())) handler.current(read);
      };
      await reader.scan({ signal: abort.signal });
      setState('scanning');
    } catch (error) {
      setState(error instanceof DOMException && error.name === 'NotAllowedError' ? 'denied' : 'error');
    }
  }, []);

  const stop = useCallback(() => {
    controller.current?.abort();
    controller.current = null;
    setState(nfcSupported() ? 'idle' : 'unsupported');
  }, []);

  return { state, start, stop };
}
