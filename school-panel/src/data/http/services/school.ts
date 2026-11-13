import type { Holiday, School, Shift } from '@/data/contracts';
import type { schoolService } from '@/data/mock/services/school';
import type { HolidayInput, SchoolProfileInput, SchoolZoneInput } from '@/data/schemas/school';
import { http } from '../client';

export const schoolHttp: typeof schoolService = {
  get: () => http<{ school: School; shifts: Shift[]; holidays: Holiday[] }>('GET', '/school/info'),
  updateProfile: (input: SchoolProfileInput) => http<School>('PUT', '/school/info', { body: input }),
  setLogo: (logo: string | null) => http<School>('PUT', '/school/logo', { body: { logo } }),
  setZone: (input: SchoolZoneInput) => http<School>('PUT', '/school/zone', { body: input }),
  clearZone: () => http<School>('DELETE', '/school/zone'),
  addHoliday: (input: HolidayInput) => http<Holiday>('POST', '/school/holidays', { body: input }),
  removeHoliday: (id: string) => http<void>('DELETE', `/school/holidays/${encodeURIComponent(id)}`),
};
