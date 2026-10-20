/**
 * Ma'lumot manbai: `mock` — brauzer xotirasidagi demo (standart), `http` —
 * Parvoz backend'i (`NEXT_PUBLIC_DATA_SOURCE=http`). Build vaqtida aniqlanadi.
 */
export const DATA_SOURCE: 'mock' | 'http' = process.env.NEXT_PUBLIC_DATA_SOURCE === 'http' ? 'http' : 'mock';

export const isHttpMode = DATA_SOURCE === 'http';

/** Backend API manzili (standart — shu domen, `/api`). */
export const API_BASE = (process.env.NEXT_PUBLIC_API_BASE ?? '/api').replace(/\/$/, '');
