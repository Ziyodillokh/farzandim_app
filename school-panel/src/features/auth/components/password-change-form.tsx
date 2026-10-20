'use client';

import { KeyRound, Lock } from 'lucide-react';
import { useState, type FormEvent } from 'react';
import { toast } from 'sonner';

import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { ServiceError } from '@/data/contracts';
import { changeHttpPassword } from '@/data/http/session';
import { useI18n } from '@/i18n';
import { errorKey } from '@/lib/errors';

/** Backend bilan bir xil qoida: kamida 10 belgi. */
const MIN_PASSWORD = 10;

type Field = 'current' | 'next' | 'confirm';

/** Parolni almashtirish formasi (majburiy ekran va profil oynasi uchun umumiy). */
export function PasswordChangeForm({ onDone }: { onDone?: () => void }) {
  const { t } = useI18n();
  const [values, setValues] = useState<Record<Field, string>>({ current: '', next: '', confirm: '' });
  const [error, setError] = useState<Partial<Record<Field, string>>>({});
  const [saving, setSaving] = useState(false);
  const set = (field: Field) => (value: string) => setValues((v) => ({ ...v, [field]: value }));

  const validate = (): Partial<Record<Field, string>> => {
    if (values.next.length < MIN_PASSWORD) return { next: t('auth.changePassword.tooShort') };
    if (values.next === values.current) return { next: t('auth.changePassword.same') };
    if (values.next !== values.confirm) return { confirm: t('auth.changePassword.mismatch') };
    return {};
  };

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    const problems = validate();
    setError(problems);
    if (Object.keys(problems).length > 0) return;
    setSaving(true);
    try {
      await changeHttpPassword(values.current, values.next);
      toast.success(t('auth.changePassword.done'));
      onDone?.();
    } catch (err) {
      const wrong = err instanceof ServiceError && err.message.startsWith('current:');
      if (wrong) setError({ current: t('auth.changePassword.wrong') });
      else toast.error(t(errorKey(err)));
    } finally {
      setSaving(false);
    }
  };

  const field = (name: Field, label: string, icon: typeof Lock, autoComplete: string) => {
    const Icon = icon;
    return (
      <div className="space-y-1.5">
        <Label htmlFor={`pw-${name}`}>{label}</Label>
        <div className="relative">
          <Icon className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            id={`pw-${name}`}
            type="password"
            autoComplete={autoComplete}
            className="pl-9"
            value={values[name]}
            onChange={(e) => set(name)(e.target.value)}
            aria-invalid={Boolean(error[name])}
          />
        </div>
        {error[name] && <p className="text-xs text-destructive">{error[name]}</p>}
      </div>
    );
  };

  return (
    <form onSubmit={(e) => void submit(e)} className="space-y-4">
      {field('current', t('auth.changePassword.current'), Lock, 'current-password')}
      {field('next', t('auth.changePassword.next'), KeyRound, 'new-password')}
      {field('confirm', t('auth.changePassword.confirm'), KeyRound, 'new-password')}
      <p className="text-xs text-muted-foreground">{t('auth.changePassword.hint')}</p>
      <Button type="submit" className="w-full" loading={saving} disabled={!values.current || !values.next || !values.confirm}>
        {t('auth.changePassword.submit')}
      </Button>
    </form>
  );
}
