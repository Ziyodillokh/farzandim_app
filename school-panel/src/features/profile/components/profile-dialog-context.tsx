'use client';

import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from 'react';

import { ProfileDialog } from './profile-dialog';

const Ctx = createContext<{ open: () => void }>({ open: () => undefined });

/** "Profilim" dialogini istalgan joydan ochish (foydalanuvchi menyusi, sidebar). */
export function ProfileDialogProvider({ children }: { children: ReactNode }) {
  const [isOpen, setOpen] = useState(false);
  const open = useCallback(() => setOpen(true), []);
  const value = useMemo(() => ({ open }), [open]);
  return (
    <Ctx.Provider value={value}>
      {children}
      <ProfileDialog open={isOpen} onOpenChange={setOpen} />
    </Ctx.Provider>
  );
}

export function useProfileDialog() {
  return useContext(Ctx);
}
