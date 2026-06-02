/**
 * Admin API methods — typed wrappers around the NestJS backend.
 *
 * Har bir method bitta domain (auth/users/content/...) ichida.
 * Backend Swagger endpointlariga 1:1 mos.
 */
import { api } from './client';
import { normalizePagination } from '@/types/api.types';
import type {
  AdminNotification,
  AdminUser,
  AdminUserListItem,
  Audiobook,
  AuditLogEntry,
  Book,
  ContentCategory,
  DashboardData,
  LoginResponse,
  Moderator,
  Olympiad,
  Paginated,
  Payment,
  Plan,
  Promocode,
  RawPaginated,
  TwoFactorStatus,
  TwoFactorVerifyResponse,
  Video,
} from '@/types/api.types';

// ───────────────────────── AUTH ─────────────────────────
export const authApi = {
  login: (email: string, password: string) =>
    api.post<LoginResponse>('/admin/auth/login', { email, password }),

  verify2fa: (challengeId: string, code: string) =>
    api.post<TwoFactorVerifyResponse>('/admin/auth/2fa/verify', { challengeId, code }),

  me: () => api.get<AdminUser>('/admin/auth/staff-me'),

  logout: () => api.post<{ ok: boolean }>('/admin/auth/logout'),

  twoFactor: {
    status: () => api.get<TwoFactorStatus>('/admin/auth/2fa/status'),
    setup: () => api.post<{ secret: string; otpauthUri: string }>('/admin/auth/2fa/setup'),
    enable: (code: string) =>
      api.post<{ enabled: boolean; backupCodes: string[] }>('/admin/auth/2fa/enable', { code }),
    disable: (password: string, code?: string) =>
      api.post<{ disabled: boolean }>('/admin/auth/2fa/disable', { password, code }),
  },

  changePassword: (currentPassword: string, newPassword: string) =>
    api.post<{ ok: boolean }>('/admin/auth/change-password', { currentPassword, newPassword }),
};

// ───────────────────────── DASHBOARD ─────────────────────────
export const dashboardApi = {
  stats: (params?: { from?: string; to?: string }) =>
    api.get<DashboardData>('/admin/dashboard', { params }),
};

// ───────────────────────── USERS ─────────────────────────
export interface UsersListParams {
  q?: string;
  role?: string;
  status?: string;
  plan?: string;
  page?: number;
  limit?: number;
}

export const usersApi = {
  list: (params: UsersListParams = {}) =>
    api.get<Paginated<AdminUserListItem>>('/admin/users', { params }),

  detail: (id: string) => api.get<AdminUserListItem & Record<string, unknown>>(`/admin/users/${id}`),

  childProfile: (id: string) => api.get<Record<string, unknown>>(`/admin/child-profiles/${id}`),

  block: (id: string) => api.post(`/admin/users/${id}/block`),
  unblock: (id: string) => api.post(`/admin/users/${id}/unblock`),
  warn: (id: string, message: string) => api.post(`/admin/users/${id}/warn`, { message }),
};

// ───────────────────────── MODERATORS ─────────────────────────
export const moderatorsApi = {
  list: (params?: { page?: number; limit?: number; q?: string }) =>
    api.get<RawPaginated<Moderator>>('/admin/moderators', { params }).then(normalizePagination),
  detail: (id: string) => api.get<Moderator>(`/admin/moderators/${id}`),
  create: (data: { name: string; email: string; phone?: string; moderatorRoleKey: string; password: string; permissions?: string[] }) =>
    api.post<Moderator>('/admin/moderators', data),
  update: (id: string, data: Partial<Moderator>) => api.patch<Moderator>(`/admin/moderators/${id}`, data),
  block: (id: string) => api.post(`/admin/moderators/${id}/block`),
  unblock: (id: string) => api.post(`/admin/moderators/${id}/unblock`),
  resetPassword: (id: string) =>
    api.post<{ password: string }>(`/admin/moderators/${id}/reset-password`),
  remove: (id: string) => api.delete(`/admin/moderators/${id}`),
};

// ───────────────────────── CONTENT ─────────────────────────
export interface ContentListParams {
  page?: number;
  limit?: number;
  status?: string;
  category?: string;
}

export const contentApi = {
  videos: {
    list: (params: ContentListParams = {}) =>
      api.get<RawPaginated<Video>>('/admin/videos', { params }).then(normalizePagination),
    detail: (id: string) => api.get<Video>(`/admin/videos/${id}`),
    create: (data: Partial<Video>) => api.post<Video>('/admin/videos/create', data),
    update: (id: string, data: Partial<Video>) => api.patch<Video>(`/admin/videos/${id}`, data),
    /** Multipart: videoFile + thumbnailFile? + metadata JSON */
    upload: (videoFile: File, metadata: Record<string, unknown>, thumbnailFile?: File | null, onProgress?: (p: number) => void) => {
      const form = new FormData();
      form.append('videoFile', videoFile);
      if (thumbnailFile) form.append('thumbnailFile', thumbnailFile);
      form.append('metadata', JSON.stringify(metadata));
      return api.postForm<Video>('/admin/videos/upload', form, onProgress);
    },
    approve: (id: string) => api.patch(`/admin/videos/${id}/approve`),
    reject: (id: string) => api.patch(`/admin/videos/${id}/reject`),
    remove: (id: string) => api.delete(`/admin/videos/${id}`),
  },
  audiobooks: {
    list: (params: ContentListParams = {}) =>
      api.get<RawPaginated<Audiobook>>('/admin/audiobooks', { params }).then(normalizePagination),
    detail: (id: string) => api.get<Audiobook>(`/admin/audiobooks/${id}`),
    upload: (audioFile: File, metadata: Record<string, unknown>, thumbnailFile?: File | null, onProgress?: (p: number) => void) => {
      const form = new FormData();
      form.append('audioFile', audioFile);
      if (thumbnailFile) form.append('thumbnailFile', thumbnailFile);
      form.append('metadata', JSON.stringify(metadata));
      return api.postForm<Audiobook>('/admin/audiobooks/upload', form, onProgress);
    },
    approve: (id: string) => api.patch(`/admin/audiobooks/${id}/approve`),
    reject: (id: string) => api.patch(`/admin/audiobooks/${id}/reject`),
    remove: (id: string) => api.delete(`/admin/audiobooks/${id}`),
  },
  books: {
    list: (params: ContentListParams = {}) =>
      api.get<RawPaginated<Book>>('/admin/books', { params }).then(normalizePagination),
    detail: (id: string) => api.get<Book>(`/admin/books/${id}`),
    create: (data: Partial<Book>) => api.post<Book>('/admin/books/create', data),
    upload: (pdfFile: File, metadata: Record<string, unknown>, coverFile?: File | null, onProgress?: (p: number) => void) => {
      const form = new FormData();
      form.append('pdfFile', pdfFile);
      if (coverFile) form.append('coverFile', coverFile);
      form.append('metadata', JSON.stringify(metadata));
      return api.postForm<Book>('/admin/books/upload', form, onProgress);
    },
    approve: (id: string) => api.patch(`/admin/books/${id}/approve`),
    reject: (id: string) => api.patch(`/admin/books/${id}/reject`),
    remove: (id: string) => api.delete(`/admin/books/${id}`),
  },
  categories: {
    list: (kind?: string) =>
      api.get<ContentCategory[]>('/admin/categories', { params: kind ? { kind } : {} }),
    create: (data: Partial<ContentCategory>) => api.post<ContentCategory>('/admin/categories', data),
  },
};

// ───────────────────────── MONETIZATION ─────────────────────────
export const monetizationApi = {
  plans: {
    list: () => api.get<Plan[]>('/admin/monetization/plans'),
    create: (data: Partial<Plan>) => api.post<Plan>('/admin/monetization/plans', data),
    update: (id: string, data: Partial<Plan>) =>
      api.patch<Plan>(`/admin/monetization/plans/${id}`, data),
  },
  promocodes: {
    list: () => api.get<Promocode[]>('/admin/monetization/promocodes'),
    create: (data: Partial<Promocode>) => api.post<Promocode>('/admin/monetization/promocodes', data),
    update: (id: string, data: Partial<Promocode>) =>
      api.patch<Promocode>(`/admin/monetization/promocodes/${id}`, data),
  },
  payments: {
    list: (params: { page?: number; limit?: number; status?: string; method?: string } = {}) =>
      api.get<RawPaginated<Payment>>('/admin/monetization/payments', { params }).then(normalizePagination),
  },
};

// ───────────────────────── NOTIFICATIONS ─────────────────────────
export const notificationsApi = {
  list: (params?: { page?: number; limit?: number; status?: string }) =>
    api.get<RawPaginated<AdminNotification>>('/admin/notifications', { params }).then(normalizePagination),
  history: () => api.get<AdminNotification[]>('/admin/notifications/history'),
  stats: () =>
    api.get<{ total: number; delivered: number; opened: number; clicked: number }>(
      '/admin/notifications/stats',
    ),
  detail: (id: string) => api.get<AdminNotification>(`/admin/notifications/${id}`),
  remove: (id: string) => api.delete(`/admin/notifications/${id}`),
  create: (data: {
    title: string;
    message: string;
    targetType: string;
    filters?: Record<string, unknown>;
    imageUrl?: string;
    deepLink?: string;
    scheduledAt?: string;
  }) => api.post<AdminNotification>('/admin/notifications', data),
  uploadImage: (file: File) => {
    const form = new FormData();
    form.append('file', file);
    return api.postForm<{ url: string }>('/admin/notifications/upload-image', form);
  },
  aiGenerate: () =>
    api.post<Array<{ title: string; message: string; targetType?: string }>>(
      '/admin/notifications/ai-generate',
    ),
};

// ───────────────────────── OLYMPIADS ─────────────────────────
export const olympiadsApi = {
  list: (params?: { page?: number; limit?: number; status?: string }) =>
    api.get<RawPaginated<Olympiad>>('/admin/olympiads', { params }).then(normalizePagination),
  detail: (id: string) => api.get<Olympiad>(`/admin/olympiads/${id}`),
  create: (data: OlympiadCreatePayload) => api.post<Olympiad>('/admin/olympiads', data),
  update: (id: string, data: Partial<OlympiadCreatePayload>) =>
    api.patch<Olympiad>(`/admin/olympiads/${id}`, data),
  publish: (id: string) => api.post(`/admin/olympiads/${id}/publish`),
  archive: (id: string) => api.post(`/admin/olympiads/${id}/archive`),
  leaderboard: (id: string, limit = 100) =>
    api.get(`/admin/olympiads/${id}/leaderboard`, { params: { limit } }),
};

export interface OlympiadQuestionInput {
  text: string;
  options: string[];
  correctIndex: number;
  points: number;
}

export interface OlympiadCreatePayload {
  title: string;
  description?: string;
  subject: string;
  ageFrom: number;
  ageTo: number;
  type: string;
  difficulty: string;
  startTime: string;
  endTime: string;
  durationMin: number;
  maxAttempts: number;
  xpReward: number;
  shuffleQuestions: boolean;
  shuffleAnswers: boolean;
  hideResults: boolean;
  allowBack: boolean;
  certificateEnabled: boolean;
  questions: OlympiadQuestionInput[];
}

// ───────────────────────── ANALYTICS ─────────────────────────
export const analyticsApi = {
  overview: () => api.get('/admin/analytics'),
  videos: () => api.get('/admin/analytics/videos'),
  monetization: () => api.get('/admin/analytics/monetization'),
};

// ───────────────────────── AUDIT LOG ─────────────────────────
export const auditApi = {
  list: (params?: {
    page?: number;
    limit?: number;
    moderatorId?: string;
    action?: string;
    from?: string;
    to?: string;
  }) => api.get<RawPaginated<AuditLogEntry>>('/admin/audit-log', { params }).then(normalizePagination),
  actions: () => api.get<string[]>('/admin/audit-log/actions'),
};
