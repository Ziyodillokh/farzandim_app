import type { EmergencyState, SchoolModeException, SchoolModePolicy, Shift } from '@/data/contracts';
import type { schoolModeService } from '@/data/mock/services/school-mode';
import type { AllowedAppInput, EmergencyInput, ExceptionInput, PolicyPatch, ShiftUpdateInput } from '@/data/schemas/school-mode';
import { http } from '../client';

type SchoolMode = typeof schoolModeService;
type Result<K extends keyof SchoolMode> = Awaited<ReturnType<SchoolMode[K]>>;
const BASE = '/school/school-mode';
const id = (v: string) => encodeURIComponent(v);

export const schoolModeHttp: SchoolMode = {
  overview: () => http<Result<'overview'>>('GET', `${BASE}/overview`),
  devices: (filter = {}) => http<Result<'devices'>>('GET', `${BASE}/devices`, { query: filter }),
  policy: () => http<SchoolModePolicy>('GET', `${BASE}/policy`),
  shifts: () => http<Result<'shifts'>>('GET', `${BASE}/shifts`),
  exceptions: (filter = {}) => http<Result<'exceptions'>>('GET', `${BASE}/exceptions`, { query: filter }),
  remindParents: (studentIds) => http<Result<'remindParents'>>('POST', `${BASE}/remind`, { body: { studentIds } }),
  updatePolicy: (input: PolicyPatch) => http<SchoolModePolicy>('PUT', `${BASE}/policy`, { body: input }),
  addAllowedApp: (input: AllowedAppInput) => http<SchoolModePolicy>('POST', `${BASE}/policy/apps`, { body: input }),
  removeAllowedApp: (appId) => http<SchoolModePolicy>('DELETE', `${BASE}/policy/apps/${id(appId)}`),
  updateShift: (shiftId, input: ShiftUpdateInput) => http<Shift>('PUT', `${BASE}/shifts/${id(shiftId)}`, { body: input }),
  createException: (input: ExceptionInput) => http<SchoolModeException>('POST', `${BASE}/exceptions`, { body: input }),
  revokeException: (exceptionId) => http<SchoolModeException>('POST', `${BASE}/exceptions/${id(exceptionId)}/revoke`),
  activateEmergency: (input: EmergencyInput) => http<EmergencyState>('POST', `${BASE}/emergency`, { body: input }),
  deactivateEmergency: () => http<EmergencyState>('POST', `${BASE}/emergency/off`),
};
