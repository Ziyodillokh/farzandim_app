'use client';

import { Copy, KeyRound } from 'lucide-react';
import { useEffect, useState } from 'react';
import { toast } from 'sonner';

import { FormField } from '@/components/common/form-field';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import type { StaffRow } from '@/data/mock/services/staff';
import { useI18n } from '@/i18n';
import { generateTempPassword, suggestUsername, USERNAME_PATTERN } from '../account';
import { useSetStaffAccount } from '../hooks';

/** Panel hisobi: login + vaqtinchalik parol (faqat shu yerda bir marta ko'rsatiladi). */
export function StaffAccountDialog({ row, onOpenChange }: { row: StaffRow | null; onOpenChange: (open: boolean) => void }) {
  const { t } = useI18n();
  const save = useSetStaffAccount();
  const [username, setUsername] = useState('');
  const [issued, setIssued] = useState<string | null>(null);

  useEffect(() => {
    if (!row) return;
    setUsername(row.username ?? suggestUsername(row.fullName));
    setIssued(null);
  }, [row]);

  const valid = USERNAME_PATTERN.test(username);
  const submit = () => {
    if (!row || !valid) return;
    const password = generateTempPassword();
    save.mutate({ id: row.id, username, password }, { onSuccess: () => setIssued(password) });
  };
  const copy = () => {
    if (!issued) return;
    void navigator.clipboard.writeText(`${username} / ${issued}`).then(() => toast.success(t('common.copied')));
  };
  // So'rov ketayotganda oyna yopilmaydi (X, Escape, tashqariga bosish): serverda o'rnatilgan parol
  // albatta bir marta ko'rsatilsin — aks holda xodim kira olmaydi va parolni qayta berish kerak bo'ladi.
  const handleOpenChange = (open: boolean) => {
    if (!open && save.isPending) return;
    onOpenChange(open);
  };

  return (
    <Dialog open={Boolean(row)} onOpenChange={handleOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{t('staff.account.title')}</DialogTitle>
          <DialogDescription>{t('staff.account.text')}</DialogDescription>
        </DialogHeader>
        {row && (
          <div className="space-y-4">
            <p className="text-sm font-medium">{row.fullName}</p>
            <FormField label={t('staff.account.username')} htmlFor="staff-username" hint={t('staff.account.usernameHint')}>
              <Input
                id="staff-username"
                autoComplete="off"
                value={username}
                disabled={Boolean(issued) || save.isPending}
                onChange={(e) => setUsername(e.target.value.trim().toLowerCase())}
              />
            </FormField>
            {issued && (
              <div className="rounded-2xl border border-brand-200 bg-brand-50/60 p-4 dark:border-brand-500/30 dark:bg-brand-500/10">
                <p className="text-xs uppercase tracking-wider text-muted-foreground">{t('staff.account.password')}</p>
                <p className="mt-1 select-all font-mono text-xl font-semibold tracking-wider">{issued}</p>
                <p className="mt-2 text-xs text-muted-foreground">{t('staff.account.passwordNote')}</p>
              </div>
            )}
          </div>
        )}
        <DialogFooter>
          {issued ? (
            <Button onClick={copy}>
              <Copy />
              {t('staff.account.copy')}
            </Button>
          ) : (
            <Button onClick={submit} loading={save.isPending} disabled={!valid}>
              <KeyRound />
              {row?.username ? t('staff.account.reset') : t('staff.account.save')}
            </Button>
          )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
