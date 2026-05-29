import axios, { AxiosError, AxiosInstance, AxiosRequestConfig } from 'axios';
import { useAuthStore } from '@/stores/auth.store';

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000/api';

/**
 * Axios client with JWT interceptors.
 *
 * Security model:
 *   - Access token: stored in memory (Zustand store), short-lived (15m)
 *   - Refresh token: NOT in localStorage (XSS). Sent with each refresh request.
 *   - On 401: attempt single refresh, then retry original request once.
 *   - On refresh failure: logout user.
 */
class ApiClient {
  private instance: AxiosInstance;
  private refreshPromise: Promise<string | null> | null = null;

  constructor() {
    this.instance = axios.create({
      baseURL: API_URL,
      timeout: 15000,
      withCredentials: true, // for cookies (admin refresh)
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
      (response) => response,
      async (error: AxiosError) => this.handleResponseError(error),
    );
  }

  private async handleResponseError(error: AxiosError) {
    const originalRequest = error.config as AxiosRequestConfig & { _retry?: boolean };

    // No response (network error)
    if (!error.response) return Promise.reject(error);

    // Not 401 or already retried — pass through
    if (error.response.status !== 401 || originalRequest._retry) {
      return Promise.reject(error);
    }

    // Don't refresh on auth endpoints
    const url = originalRequest.url || '';
    if (url.includes('/auth/refresh') || url.includes('/auth/telegram') || url.includes('/auth/login')) {
      return Promise.reject(error);
    }

    originalRequest._retry = true;

    try {
      const newToken = await this.refreshAccessToken();
      if (!newToken) {
        useAuthStore.getState().logout();
        return Promise.reject(error);
      }
      if (originalRequest.headers) {
        originalRequest.headers.Authorization = `Bearer ${newToken}`;
      }
      return this.instance(originalRequest);
    } catch (refreshError) {
      useAuthStore.getState().logout();
      return Promise.reject(refreshError);
    }
  }

  /** Single in-flight refresh — multiple concurrent 401s share one refresh call. */
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
        `${API_URL}/auth/refresh`,
        { refreshToken },
        { timeout: 10000 },
      );
      const newAccess = data.accessToken as string;
      const newRefresh = (data.refreshToken as string) || refreshToken;
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
