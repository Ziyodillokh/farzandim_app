import type { MyProfile, StaffAvatarInfo, profileService } from '@/data/mock/services/profile';
import { http } from '../client';

export const profileHttp: typeof profileService = {
  me: () => http<MyProfile>('GET', '/school/profile/me'),
  avatars: () => http<Record<string, StaffAvatarInfo>>('GET', '/school/profile/avatars'),
  // Haqiqiy rejimda demo hisoblar yo'q.
  demoProfiles: async () => ({}),
  setPhoto: (staffId, photo) => http<StaffAvatarInfo>('PUT', `/school/profile/photo/${encodeURIComponent(staffId)}`, { body: { photo } }),
};
