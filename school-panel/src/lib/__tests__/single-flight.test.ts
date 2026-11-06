import { describe, expect, it, vi } from 'vitest';

import { singleFlight } from '../single-flight';

/** Tashqaridan hal qilinadigan va'da. */
function deferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (reason: unknown) => void;
  const promise = new Promise<T>((res, rej) => {
    resolve = res;
    reject = rej;
  });
  return { promise, resolve, reject };
}

describe('singleFlight', () => {
  it('tugamaguncha qayta chaqirilsa — yangi so\'rov yo\'q, o\'sha va\'da qaytadi (dblclick ikki marta yaratmaydi)', async () => {
    const gate = deferred<string>();
    const fn = vi.fn(() => gate.promise);
    const once = singleFlight(fn);

    const first = once();
    const second = once();
    expect(fn).toHaveBeenCalledTimes(1);
    expect(second).toBe(first);

    gate.resolve('kod-1');
    await expect(first).resolves.toBe('kod-1');
  });

  it('tugagach (muvaffaqiyat yoki xato) keyingi chaqiruv yangi so\'rov yuboradi', async () => {
    const fn = vi.fn().mockResolvedValueOnce('a').mockRejectedValueOnce(new Error('x')).mockResolvedValueOnce('c');
    const once = singleFlight(fn);

    await expect(once()).resolves.toBe('a');
    await expect(once()).rejects.toThrow('x');
    await expect(once()).resolves.toBe('c');
    expect(fn).toHaveBeenCalledTimes(3);
  });

  it('birinchi chaqiruv argumentlari ishlatiladi; ikkinchisiniki e\'tiborsiz', async () => {
    const gate = deferred<void>();
    const calls: string[] = [];
    const once = singleFlight((input: string) => {
      calls.push(input);
      return gate.promise;
    });
    void once('birinchi');
    void once('ikkinchi');
    expect(calls).toEqual(['birinchi']);
    gate.resolve();
  });
});
