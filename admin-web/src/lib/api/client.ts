import axios, { type AxiosError, type AxiosInstance, type AxiosRequestConfig } from 'axios';
import { useAuthStore } from '@/stores/auth.store';

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000/api';

/**
 * Admin API client (Axios) — JWT bearer + refresh rotation.
 *
 * Interceptor pipeline:
 *   1) Request: attach Authorization header (if access token mavjud)
 *   2) Response: 401 → bir martagina refresh → orig request retry
 *                Refresh fail bo'lsa logout + login'ga redirect
 *   3) Concurrent 401: bitta in-flight refresh, qolganlari kutadi (refreshPromise)
 */
class ApiClient {
  private instance: AxiosInstance;
  private refreshPromise: Promise<string | null> | null = null;

  constructor() {
    this.instance = axios.create({
      baseURL: API_URL,
      timeout: 20000,
      withCredentials: true,
      headers: { 'Content-Type': 'application/json' },
    });

    this.instance.interceptors.request.use((config) => {
      const token = useAuthStore.getState().accessToken;
      if (token && config.headers) {
        config.headers.Authorization = `Bearer ${token}`;
      }
      return config;
    });

    this.instance.interceptors.response.use(
      (r) => r,
      (error: AxiosError) => this.handleResponseError(error),
    );
  }

  private async handleResponseError(error: AxiosError) {
    const original = error.config as AxiosRequestConfig & { _retry?: boolean };
    if (!error.response) return Promise.reject(error);

    const status = error.response.status;
    const url = original?.url ?? '';

    // 401 — try refresh once (skip on auth endpoints)
    const isAuthPath =
      url.includes('/admin/auth/login') ||
      url.includes('/admin/auth/refresh') ||
      url.includes('/admin/auth/2fa/verify');

    if (status === 401 && !original._retry && !isAuthPath) {
      original._retry = true;
      try {
        const newToken = await this.refreshAccessToken();
        if (!newToken) {
          useAuthStore.getState().logout();
          if (typeof window !== 'undefined') window.location.href = '/login';
          return Promise.reject(error);
        }
        if (original.headers) original.headers.Authorization = `Bearer ${newToken}`;
        return this.instance(original);
      } catch {
        useAuthStore.getState().logout();
        if (typeof window !== 'undefined') window.location.href = '/login';
        return Promise.reject(error);
      }
    }

    // 403 — permission denied, keep on page, surface error
    return Promise.reject(error);
  }

  private refreshAccessToken(): Promise<string | null> {
    if (!this.refreshPromise) {
      this.refreshPromise = this.doRefresh().finally(() => {
        this.refreshPromise = null;
      });
    }
    return this.refreshPromise;
  }

  private async doRefresh(): Promise<string | null> {
    const refreshToken = useAuthStore.getState().refreshToken;
    if (!refreshToken) return null;
    try {
      const { data } = await axios.post(
        `${API_URL}/admin/auth/refresh`,
        { refreshToken },
        { withCredentials: true, timeout: 12000 },
      );
      const newAccess = (data.access_token ?? data.accessToken) as string;
      const newRefresh = (data.refresh_token ?? data.refreshToken ?? refreshToken) as string;
      useAuthStore.getState().setTokens(newAccess, newRefresh);
      return newAccess;
    } catch {
      return null;
    }
  }

  get<T>(url: string, config?: AxiosRequestConfig) {
    return this.instance.get<T>(url, config).then((r) => r.data);
  }
  post<T>(url: string, data?: unknown, config?: AxiosRequestConfig) {
    return this.instance.post<T>(url, data, config).then((r) => r.data);
  }
  /** Multipart upload (FormData). onProgress optional. */
  postForm<T>(url: string, form: FormData, onProgress?: (pct: number) => void) {
    return this.instance
      .post<T>(url, form, {
        headers: { 'Content-Type': 'multipart/form-data' },
        timeout: 25 * 60 * 1000, // 25 daqiqa — katta video upload uchun
        onUploadProgress: (e) => {
          if (onProgress && e.total) onProgress(Math.round((e.loaded / e.total) * 100));
        },
      })
      .then((r) => r.data);
  }
  put<T>(url: string, data?: unknown, config?: AxiosRequestConfig) {
    return this.instance.put<T>(url, data, config).then((r) => r.data);
  }
  patch<T>(url: string, data?: unknown, config?: AxiosRequestConfig) {
    return this.instance.patch<T>(url, data, config).then((r) => r.data);
  }
  delete<T>(url: string, config?: AxiosRequestConfig) {
    return this.instance.delete<T>(url, config).then((r) => r.data);
  }
}

export const api = new ApiClient();

/** Axios xatosidan foydalanuvchi uchun xabar olish. */
export function getApiErrorMessage(err: unknown): string {
  if (axios.isAxiosError(err)) {
    const data = err.response?.data as { message?: string | string[]; error?: string } | undefined;
    if (data?.message) {
      return Array.isArray(data.message) ? data.message.join(', ') : data.message;
    }
    if (data?.error) return data.error;
    if (err.code === 'ECONNABORTED') return "So'rov muddati tugadi";
    if (err.code === 'ERR_NETWORK') return 'Tarmoq xatosi — backend ulanmadi';
    return err.message || 'Noma\'lum xato';
  }
  return err instanceof Error ? err.message : 'Noma\'lum xato';
}
