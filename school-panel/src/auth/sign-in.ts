import type { AuditLog } from '@/data/contracts';
import { toLocalIso } from '@/data/mock/calendar';
import { clockNow } from '@/data/mock/clock';
import { transact } from '@/data/mock/db';
import { ensureDemoFresh } from '@/data/mock/freshness';
import type { DemoAccount } from './demo-accounts';
import { type Session, type SessionScope, setSession } from './session';

export type SignInOptions = {
  /** Audit amali (standart: `auth.login`). */
  action?: string;
  summary?: string;
  /** Kim bajardi (masalan, kioskni ochgan direktor); standart — kirayotgan hisobning o'zi. */
  by?: Pick<Session, 'staffId' | 'username'> | null;
};

const DEFAULT_SUMMARY = 'Panelga kirdi';

/**
 * Demo kirish: demo ma'lumotlarini bugunga moslaydi, auditga yozadi va sessiyani
 * o'rnatadi. `tab` — faqat shu tab (demo rol almashtirish, kiosk "navbatchi sifatida").
 */
export function signIn(account: DemoAccount, scope: SessionScope, options: SignInOptions = {}): Session {
  // Avval: baza qayta yaratilsa ham kirish yozuvi yo'qolmasin.
  ensureDemoFresh();
  const by = options.by ?? { staffId: account.staffId, username: account.username };
  transact((tables) => {
    const actor = tables.staff.find((s) => s.id === by.staffId);
    const entry: AuditLog = {
      id: `aud-login-${Date.now()}`,
      at: toLocalIso(clockNow()),
      actorId: by.staffId,
      actorName: actor?.fullName ?? by.username,
      module: 'AUTH',
      action: options.action ?? 'auth.login',
      entityId: by.staffId === account.staffId ? null : account.staffId,
      summary: options.summary ?? DEFAULT_SUMMARY,
      before: null,
      after: null,
    };
    tables.audit.push(entry);
  });
  const session: Session = { staffId: account.staffId, username: account.username, role: account.role, loggedInAt: new Date().toISOString() };
  setSession(session, scope);
  return session;
}
