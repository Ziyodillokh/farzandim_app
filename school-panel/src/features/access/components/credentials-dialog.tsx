'use client';

import { Copy, KeyRound, Printer, TriangleAlert } from 'lucide-react';
import { type FormEvent, useCallback, useEffect, useRef, useState } from 'react';
import { toast } from 'sonner';

import { FormField } from '@/components/common/form-field';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Switch } from '@/components/ui/switch';
import type { IssuedCredentials } from '@/data/contracts';
import { issueCredentialsSchema, LOGIN_MAX } from '@/data/schemas/access';
import { INNER_TILE } from '@/features/classes/styles';
import { useCopy } from '@/features/parents/hooks';
import { useSchool } from '@/features/school/hooks';
import { useI18n } from '@/i18n';
import { errorDetail, errorKey } from '@/lib/errors';
import { cn } from '@/lib/utils';
import { useIssueCredentials } from '../hooks';
import { CredentialPrintCard } from './credential-print-card';
import { PrintOnly } from './print-only';

export type CredentialsMode = 'issue' | 'reset';

/** Bir martalik parol ochiq qoldirilgan ish joyida cheksiz turmasin: shu muddatdan keyin oyna o'zi yopiladi. */
export const REVEAL_TTL_MS = 5 * 60_000;

type Props = {
  studentId: string;
  studentName: string;
  className: string;
  mode: CredentialsMode;
  /** Oyna yopiladi — ota komponent uni olib tashlaydi (parol holatda ham qolmaydi). */
  onClose: () => void;
  /** Backend `NOT_LINKED` desa — ota karta holatni yangilaydi. */
  onNotLinked: () => void;
  /** Yopilgach fokus oynani ochgan tugmaga qaytadi. */
  onCloseAutoFocus: (event: Event) => void;
};

type Step = 'form' | 'reveal';

function SecretRow({
  label,
  value,
  copyLabel,
  onCopy,
  mono,
  buttonRef,
  testId,
}: {
  label: string;
  value: string;
  copyLabel: string;
  onCopy: () => void;
  mono?: boolean;
  buttonRef?: React.Ref<HTMLButtonElement>;
  testId: string;
}) {
  return (
    <div className={cn('flex items-center justify-between gap-3 p-3', INNER_TILE)}>
      <div className="min-w-0">
        <p className="text-2xs font-semibold uppercase tracking-[0.08em] text-muted-foreground">{label}</p>
        <p data-testid={testId} className={cn('mt-1 select-all break-all text-lg font-semibold', mono && 'font-mono tracking-[0.12em]')}>
          {value}
        </p>
      </div>
      <Button ref={buttonRef} type="button" variant="outline" size="icon" onClick={onCopy} aria-label={copyLabel} title={copyLabel}>
        <Copy />
      </Button>
    </div>
  );
}

/** `active` davomida `REVEAL_TTL_MS` o'tsa yoki sahifa yashirilsa (yopish, bfcache) `onExpire`. */
function useRevealExpiry(active: boolean, onExpire: () => void): void {
  const latest = useRef(onExpire);
  useEffect(() => {
    latest.current = onExpire;
  });
  useEffect(() => {
    if (!active) return;
    const expire = () => latest.current();
    const timer = window.setTimeout(expire, REVEAL_TTL_MS);
    window.addEventListener('pagehide', expire);
    return () => {
      window.clearTimeout(timer);
      window.removeEventListener('pagehide', expire);
    };
  }, [active]);
}

/**
 * Kirish ma'lumotlarini berish / parolni tiklash: 1) tasdiqlash (login, «boshqa qurilmalardan chiqarish»), 2) bir martalik
 * ochish (login + vaqtinchalik parol, nusxalash, chop etish). Parol FAQAT shu komponent holatida yashaydi: oyna yopilganda
 * komponent olib tashlanadi (state yo'qoladi); URL, storage, RQ keshi, toast va logga yozilmaydi.
 */
export function CredentialsDialog({ studentId, studentName, className, mode, onClose, onNotLinked, onCloseAutoFocus }: Props) {
  const { t } = useI18n();
  const copy = useCopy();
  const school = useSchool();
  const { issue, pending } = useIssueCredentials(studentId);
  const [step, setStep] = useState<Step>('form');
  const [login, setLogin] = useState('');
  const [signOut, setSignOut] = useState(true);
  const [loginError, setLoginError] = useState<string | null>(null);
  const [issued, setIssued] = useState<IssuedCredentials | null>(null);
  const [printJob, setPrintJob] = useState(0);
  const alive = useRef(true);
  const passwordCopy = useRef<HTMLButtonElement>(null);
  const reset = mode === 'reset';

  useEffect(() => {
    alive.current = true;
    return () => {
      alive.current = false;
    };
  }, []);

  useEffect(() => {
    if (step === 'reveal') passwordCopy.current?.focus();
  }, [step]);

  useRevealExpiry(step === 'reveal', () => {
    toast.info(t('access.reveal.expired'));
    onClose();
  });

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    if (pending) return;
    // Tiklashda login o'zgarmaydi; birinchi berishda — ixtiyoriy, mock va forma bir xil sxema bilan tekshiriladi.
    const parsed = issueCredentialsSchema.safeParse({ login: reset ? '' : login, signOutDevices: reset ? signOut : undefined });
    if (!parsed.success) {
      setLoginError(t('errors.form.invalidLogin'));
      return;
    }
    setLoginError(null);
    try {
      const result = await issue({ ...(parsed.data.login ? { login: parsed.data.login } : {}), ...(reset ? { signOutDevices: signOut } : {}) });
      if (!alive.current) return;
      setIssued(result);
      setStep('reveal');
      toast.success(t(reset ? 'access.toast.reset' : 'access.toast.issued'));
    } catch (error) {
      if (!alive.current) return;
      const detail = errorDetail(error);
      if (detail === 'LOGIN_TAKEN') {
        setLoginError(t('errors.detail.LOGIN_TAKEN'));
        return;
      }
      toast.error(t(errorKey(error)));
      if (detail === 'NOT_LINKED') {
        onNotLinked();
        onClose();
      }
    }
  };

  const donePrinting = useCallback(() => setPrintJob(0), []);

  const requestClose = (open: boolean) => {
    // So'rov ketayotganda yopilmaydi: natija (parol) yo'qolib qolmasin.
    if (!open && !pending) onClose();
  };

  return (
    <Dialog open onOpenChange={requestClose}>
      <DialogContent
        className="sm:max-w-md"
        onCloseAutoFocus={onCloseAutoFocus}
        onPointerDownOutside={(e) => step === 'reveal' && e.preventDefault()}
        onInteractOutside={(e) => step === 'reveal' && e.preventDefault()}
      >
        {step === 'form' && (
          <form onSubmit={(e) => void submit(e)} noValidate className="grid gap-4">
            <DialogHeader>
              <DialogTitle>{t(reset ? 'access.issueDialog.resetTitle' : 'access.issueDialog.issueTitle')}</DialogTitle>
              <DialogDescription>{t(reset ? 'access.issueDialog.resetText' : 'access.issueDialog.issueText', { name: studentName })}</DialogDescription>
            </DialogHeader>
            {reset ? (
              <div className={cn('flex items-start justify-between gap-4 p-3.5', INNER_TILE)}>
                <div className="min-w-0 space-y-1">
                  <Label htmlFor="sign-out-devices" className="leading-snug">
                    {t('access.issueDialog.signOut')}
                  </Label>
                  <p id="sign-out-hint" className="text-xs leading-relaxed text-muted-foreground">
                    {t('access.issueDialog.signOutHint')}
                  </p>
                </div>
                <Switch id="sign-out-devices" checked={signOut} onCheckedChange={setSignOut} aria-describedby="sign-out-hint" />
              </div>
            ) : (
              <FormField
                label={t('access.issueDialog.loginLabel')}
                htmlFor="credential-login"
                optional
                hint={t('access.issueDialog.loginHint')}
                error={loginError ? { message: loginError } : undefined}
              >
                <Input
                  id="credential-login"
                  value={login}
                  onChange={(e) => {
                    setLogin(e.target.value);
                    setLoginError(null);
                  }}
                  placeholder={t('access.issueDialog.loginPlaceholder')}
                  maxLength={LOGIN_MAX}
                  autoComplete="off"
                  autoCapitalize="none"
                  autoCorrect="off"
                  spellCheck={false}
                  aria-invalid={Boolean(loginError)}
                  autoFocus
                />
                {/* Xato matni ekran o'qish dasturiga darhol e'lon qilinadi (ko'rinadigan xabar FormField'da). */}
                {loginError && (
                  <span role="alert" className="sr-only">
                    {loginError}
                  </span>
                )}
              </FormField>
            )}
            <DialogFooter>
              <Button type="button" variant="outline" onClick={() => requestClose(false)} disabled={pending}>
                {t('common.cancel')}
              </Button>
              <Button type="submit" loading={pending}>
                <KeyRound />
                {t(reset ? 'access.issueDialog.submitReset' : 'access.issueDialog.submitIssue')}
              </Button>
            </DialogFooter>
          </form>
        )}

        {step === 'reveal' && issued && (
          <div className="grid gap-4">
            <DialogHeader>
              <DialogTitle>{t('access.reveal.title')}</DialogTitle>
              <DialogDescription>{t('access.reveal.description', { name: studentName })}</DialogDescription>
            </DialogHeader>
            <p role="note" className="flex items-start gap-2.5 rounded-xl bg-warning/10 p-3 text-sm font-medium leading-relaxed ring-1 ring-inset ring-warning/25">
              <TriangleAlert className="mt-0.5 h-4 w-4 shrink-0 text-warning" aria-hidden />
              {t('access.reveal.warning')}
            </p>
            <SecretRow
              label={t('access.reveal.login')}
              value={issued.login}
              copyLabel={t('access.reveal.copyLogin')}
              onCopy={() => void copy(issued.login)}
              testId="issued-login"
            />
            <SecretRow
              label={t('access.reveal.password')}
              value={issued.temporaryPassword}
              copyLabel={t('access.reveal.copyPassword')}
              onCopy={() => void copy(issued.temporaryPassword)}
              mono
              buttonRef={passwordCopy}
              testId="issued-password"
            />
            <p className="text-sm text-muted-foreground">{t('access.reveal.firstLogin')}</p>
            <DialogFooter>
              <Button type="button" variant="outline" onClick={() => setPrintJob((n) => n + 1)}>
                <Printer />
                {t('access.reveal.print')}
              </Button>
              <Button type="button" onClick={onClose}>
                {t('access.reveal.done')}
              </Button>
            </DialogFooter>
            <PrintOnly job={printJob} onDone={donePrinting}>
              <CredentialPrintCard issued={issued} studentName={studentName} className={className} school={school.data?.school} />
            </PrintOnly>
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
}
