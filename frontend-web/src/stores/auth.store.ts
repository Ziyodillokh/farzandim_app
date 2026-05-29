import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';

export interface User {
  id: string;
  name: string | null;
  phone: string | null;
  role: 'PARENT' | 'CHILD';
  avatarUrl: string | null;
  telegramId: string | null;
  language: string;
}

interface AuthState {
  user: User | null;
  accessToken: string | null;
  refreshToken: string | null;
  isAuthenticated: boolean;
  setAuth: (user: User, accessToken: string, refreshToken: string) => void;
  setTokens: (accessToken: string, refreshToken: string) => void;
  setUser: (user: User) => void;
  logout: () => void;
}

/**
 * Auth store with selective persistence.
 *
 * SECURITY NOTE:
 *   - Refresh token persisted to localStorage (acceptable trade-off for SPA)
 *   - Access token also persisted (re-validated on app load via /users/me)
 *   - For higher security: move refresh token to HttpOnly cookie (backend already supports it for admin)
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
        set({ accessToken, refreshToken }),

      setUser: (user) => set({ user }),

      logout: () =>
        set({
          user: null,
          accessToken: null,
          refreshToken: null,
          isAuthenticated: false,
        }),
    }),
    {
      name: 'farzandim-auth',
      storage: createJSONStorage(() => localStorage),
    },
  ),
);
