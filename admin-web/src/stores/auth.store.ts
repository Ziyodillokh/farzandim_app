import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import type { AdminUser } from '@/types/api.types';

interface AuthState {
  user: AdminUser | null;
  accessToken: string | null;
  refreshToken: string | null;
  isAuthenticated: boolean;
  setAuth: (user: AdminUser, accessToken: string, refreshToken: string) => void;
  setTokens: (accessToken: string, refreshToken?: string) => void;
  setUser: (user: AdminUser) => void;
  logout: () => void;
}

/**
 * Admin auth store.
 *
 * Security:
 * - Refresh token storage: localStorage (HttpOnly cookie variant'i backend
 *   browser detection bilan beriladi; native client'lar uchun body'da keladi).
 * - Access token in-memory + persisted (re-validated on app load via /staff-me).
 */
export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      user: null,
      accessToken: null,
      refreshToken: null,
      isAuthenticated: false,

      setAuth: (user, accessToken, refreshToken) =>
        set({ user, accessToken, refreshToken, isAuthenticated: true }),

      setTokens: (accessToken, refreshToken) =>
        set((state) => ({
          accessToken,
          refreshToken: refreshToken ?? state.refreshToken,
        })),

      setUser: (user) => set({ user }),

      logout: () =>
        set({ user: null, accessToken: null, refreshToken: null, isAuthenticated: false }),
    }),
    {
      name: 'farzandim-admin-auth',
      storage: createJSONStorage(() => localStorage),
    },
  ),
);
