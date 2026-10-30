import type { DemoAccount } from './demo-accounts';
import { type Session, setSession } from './session';

/** Demo kirish: sessiyani o'rnatadi (panel faqat o'qiydi — audit yo'q). */
export function signIn(account: DemoAccount): Session {
  const session: Session = {
    username: account.username,
    role: account.role,
    regionId: account.regionId,
    loggedInAt: new Date().toISOString(),
  };
  setSession(session);
  return session;
}

export function signOut(): void {
  setSession(null);
}
