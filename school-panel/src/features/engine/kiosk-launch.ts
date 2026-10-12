import { DEMO_ACCOUNTS, type DemoAccount } from '@/auth/demo-accounts';
import { getSession, getSharedSession, type Session } from '@/auth/session';
import { signIn } from '@/auth/sign-in';
import { withBase } from '@/lib/base-path';

/**
 * Demo: kirish nuqtasini (kiosk) navbatchi hisobida ochish — faqat shu tabda
 * (sessionStorage), boshqa tablar (masalan, direktor paneli) o'z rolida qoladi.
 */
export const KIOSK_AS_PARAM = 'as';
export const KIOSK_AS_DUTY = 'navbatchi';
const KIOSK_AUDIT_ACTION = 'auth.kiosk.demo';
const KIOSK_AUDIT_SUMMARY = 'Demo: kirish nuqtasi navbatchi sifatida ochildi';

function dutyAccount(): DemoAccount | null {
  return DEMO_ACCOUNTS.find((a) => a.username === KIOSK_AS_DUTY) ?? null;
}

export function kioskDemoUrl(): string {
  return withBase(`/kiosk/?${KIOSK_AS_PARAM}=${KIOSK_AS_DUTY}`);
}

/** Yangi tab ochadi; brauzer to'sib qo'ysa — false. */
export function openKioskAsDuty(): boolean {
  const opened = window.open(kioskDemoUrl(), '_blank');
  if (!opened) return false;
  // Yangi tab bu oynani boshqara olmasin (noopener ekvivalenti, lekin to'silganini bilamiz).
  opened.opener = null;
  return true;
}

/** Shu tabni navbatchi hisobiga o'tkazadi (audit: kim ochdi). */
export function signInKioskDuty(by: Pick<Session, 'staffId' | 'username'> | null): boolean {
  const duty = dutyAccount();
  if (!duty) return false;
  signIn(duty, 'tab', { action: KIOSK_AUDIT_ACTION, summary: KIOSK_AUDIT_SUMMARY, by });
  return true;
}

/**
 * Kiosk sahifasi ochilganda: `?as=navbatchi` va umumiy sessiya bo'lsa — navbatchi
 * sifatida kiradi va so'rov qatorini tozalaydi. Boshqa qiymatlar e'tiborsiz.
 */
export function acceptKioskDemoParam(): boolean {
  const params = new URLSearchParams(window.location.search);
  const as = params.get(KIOSK_AS_PARAM);
  if (as === null) return false;
  params.delete(KIOSK_AS_PARAM);
  const query = params.toString();
  history.replaceState(history.state, '', `${window.location.pathname}${query ? `?${query}` : ''}${window.location.hash}`);
  const shared = getSharedSession();
  if (as !== KIOSK_AS_DUTY || !shared) return false;
  if (getSession()?.role === 'DUTY') return true;
  return signInKioskDuty(shared);
}
