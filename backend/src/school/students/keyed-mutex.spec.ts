import { KeyedMutex } from './keyed-mutex';

const tick = () => new Promise<void>((resolve) => setImmediate(resolve));

describe('KeyedMutex', () => {
  it('runs tasks with the same key one at a time, in arrival order', async () => {
    const mutex = new KeyedMutex();
    const log: string[] = [];
    const task = (name: string, ticks: number) => () =>
      (async () => {
        log.push(`start ${name}`);
        for (let i = 0; i < ticks; i += 1) await tick();
        log.push(`end ${name}`);
        return name;
      })();

    const results = await Promise.all([
      mutex.runExclusive(['k'], task('a', 3)),
      mutex.runExclusive(['k'], task('b', 1)),
      mutex.runExclusive(['k'], task('c', 2)),
    ]);

    expect(results).toEqual(['a', 'b', 'c']);
    expect(log).toEqual(['start a', 'end a', 'start b', 'end b', 'start c', 'end c']);
  });

  it('lets different keys run in parallel', async () => {
    const mutex = new KeyedMutex();
    const log: string[] = [];
    const slow = mutex.runExclusive(['a'], async () => {
      log.push('a start');
      await tick();
      await tick();
      log.push('a end');
    });
    const fast = mutex.runExclusive(['b'], async () => {
      log.push('b start');
      log.push('b end');
    });

    await Promise.all([slow, fast]);

    expect(log).toEqual(['a start', 'b start', 'b end', 'a end']);
  });

  it('holds all keys of one call and never deadlocks on opposite key order', async () => {
    const mutex = new KeyedMutex();
    const order: string[] = [];

    await Promise.all([
      mutex.runExclusive(['x', 'y'], async () => {
        order.push('1');
        await tick();
      }),
      mutex.runExclusive(['y', 'x'], async () => {
        order.push('2');
        await tick();
      }),
      mutex.runExclusive(['x'], async () => void order.push('3')),
    ]);

    expect(order).toEqual(['1', '2', '3']);
  });

  it('releases the keys when the task throws, propagates the error and forgets idle keys', async () => {
    const mutex = new KeyedMutex();

    await expect(mutex.runExclusive(['k'], async () => Promise.reject(new Error('boom')))).rejects.toThrow('boom');
    await expect(mutex.runExclusive(['k'], async () => 'next')).resolves.toBe('next');

    expect(mutex.activeKeys).toBe(0);
  });

  it('deduplicates repeated keys in one call', async () => {
    const mutex = new KeyedMutex();

    await expect(mutex.runExclusive(['k', 'k'], async () => 'ok')).resolves.toBe('ok');
  });
});
