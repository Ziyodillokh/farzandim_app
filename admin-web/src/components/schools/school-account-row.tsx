'use client';

/**
 * Admin boshqaradigan hisob (direktor / psixolog): holati va «Parolni tiklash».
 * Tiklash — yangi vaqtinchalik parol, blok ochiladi, barcha sessiyalar yopiladi;
 * ixtiyoriy 2FA o'chiriladi. Login yo'q bo'lsa (direktor hisobni o'chirgan) —
 * yangi login so'raladi.
 */

import { useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';
import { KeyRound, Loader2 } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { schoolsApi } from '@/lib/api/admin.api';
import { formatRelative } from '@/lib/utils';
import type { AdminSchool, AdminSchoolAccount } from '@/types/api.types';
import type { ShownCredentials } from './credentials-dialog';
import { usernameError } from './school-form';
import { ROLE_LABEL } from './school-format';
import { schoolsErrorMessage } from './schools-errors';
import { schoolsKeys } from './schools-keys';

export function SchoolAccountRow({
  school,
  account: a,
  onCredentials,
}: {
  school: AdminSchool;
  account: AdminSchoolAccount;
  onCredentials: (c: ShownCredentials) => void;
}) {
  const qc = useQueryClient();
  const [confirming, setConfirming] = useState(false);
  const [resetTotp, setResetTotp] = useState(false);
  const [username, setUsername] = useState('');
  const needsUsername = a.username === null;
  const loginError = needsUsername && username ? usernameError(username) : undefined;

  const reset = useMutation({
    mutationFn: () =>
      schoolsApi.resetPassword(school.id, a.id, {
        resetTotp,
        ...(needsUsername && { username: username.trim().toLowerCase() }),
      }),
    onSuccess: (credentials) => {
      void qc.invalidateQueries({ queryKey: schoolsKeys.all });
      setConfirming(false);
      onCredentials({
        ...credentials,
        title: 'Yangi vaqtinchalik parol',
        schoolName: school.name,
      });
    },
    onError: (e) => toast.error(schoolsErrorMessage(e)),
  });

  const canSubmit = !needsUsername || (username.trim() !== '' && !loginError);

  return (
    <li className="space-y-3 rounded-xl border border-border p-4">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="font-medium">{a.fullName}</p>
          <p className="text-xs text-muted-foreground">
            {ROLE_LABEL[a.role]}
            {a.username ? (
              <>
                {' · login '}
                <span className="font-mono text-foreground">{a.username}</span>
              </>
            ) : (
              " · login yo'q"
            )}
          </p>
          <div className="mt-2 flex flex-wrap gap-1.5">
            {!a.active && (
              <Badge variant="destructive" size="sm">
                Faol emas (direktor o&apos;chirgan)
              </Badge>
            )}
            {a.locked && (
              <Badge variant="destructive" size="sm">
                Bloklangan — ko&apos;p xato urinish
              </Badge>
            )}
            {a.mustChangePassword ? (
              <Badge variant="info" size="sm">
                Vaqtinchalik parol — hali almashtirmagan
              </Badge>
            ) : (
              <Badge variant="success" size="sm">
                Oxirgi kirish: {formatRelative(a.lastLoginAt)}
              </Badge>
            )}
            {a.totpEnabled && (
              <Badge variant="outline" size="sm">
                2FA yoqilgan
              </Badge>
            )}
          </div>
        </div>
        {!confirming && (
          <Button variant="outline" size="sm" onClick={() => setConfirming(true)}>
            <KeyRound className="h-4 w-4" /> Parolni tiklash
          </Button>
        )}
      </div>

      {confirming && (
        <div className="space-y-3 rounded-lg bg-muted/40 p-3 text-sm">
          <p>Yangi vaqtinchalik parol yaratiladi. Eski parol va barcha ochiq sessiyalar darhol ishlamay qoladi.</p>
          {needsUsername && (
            <div className="space-y-1.5">
              <Label htmlFor={`reset-username-${a.id}`}>Yangi login</Label>
              <Input
                id={`reset-username-${a.id}`}
                value={username}
                autoCapitalize="none"
                spellCheck={false}
                className="font-mono"
                placeholder="psixolog"
                onChange={(e) => setUsername(e.target.value.toLowerCase())}
              />
              {loginError && <p className="text-xs text-destructive">{loginError}</p>}
            </div>
          )}
          {a.totpEnabled && (
            <label className="flex cursor-pointer items-center gap-2">
              <Checkbox checked={resetTotp} onCheckedChange={(v) => setResetTotp(v === true)} />
              Ikki bosqichli kirishni (2FA) ham o&apos;chirish — telefon yo&apos;qolgan bo&apos;lsa
            </label>
          )}
          <div className="flex justify-end gap-2">
            <Button variant="ghost" size="sm" onClick={() => setConfirming(false)}>
              Bekor qilish
            </Button>
            <Button size="sm" onClick={() => reset.mutate()} disabled={reset.isPending || !canSubmit}>
              {reset.isPending && <Loader2 className="h-4 w-4 animate-spin" />}
              Tiklash
            </Button>
          </div>
        </div>
      )}
    </li>
  );
}
