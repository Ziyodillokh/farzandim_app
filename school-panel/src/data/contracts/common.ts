/** Barcha ID'lar — satr. Sanalar — ISO 8601. Vaqt — "HH:MM". Hafta kuni — ISO 1..7. */
export type Id = string;
export type IsoDate = string; // "2026-10-12"
export type IsoDateTime = string; // "2026-10-12T08:03:00.000Z"
export type HhMm = string; // "08:30"
export type IsoWeekday = 1 | 2 | 3 | 4 | 5 | 6 | 7;

export type Pagination = { page: number; limit: number; total: number; totalPages: number };
export type Paginated<T> = { items: T[]; pagination: Pagination };

export type SortDir = 'asc' | 'desc';
export type ListQuery = {
  page?: number;
  limit?: number;
  search?: string;
  sortBy?: string;
  sortDir?: SortDir;
};

export type Gender = 'MALE' | 'FEMALE';
export type DeviceOs = 'IOS' | 'ANDROID' | 'NONE';

/** Servis xatosi — UI uni toast/forma xatosiga aylantiradi. */
export class ServiceError extends Error {
  constructor(
    public readonly code: 'FORBIDDEN' | 'NOT_FOUND' | 'VALIDATION' | 'CONFLICT' | 'UNKNOWN',
    message: string,
  ) {
    super(message);
    this.name = 'ServiceError';
  }
}
