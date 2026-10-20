import { ServiceError } from '@/data/contracts';

/**
 * Hali backend'ga ulanmagan nom maydoni (http rejim): har chaqiruv aniq xato
 * beradi — mock ma'lumoti http sessiyasi bilan aralashmasin.
 */
export function notAvailable<T extends object>(namespace: string): T {
  return new Proxy({} as T, {
    get(_target, method) {
      return () => {
        throw new ServiceError('UNKNOWN', `${namespace}.${String(method)}: backend'da hali yo'q`);
      };
    },
  });
}
