'use client';

/**
 * Hisob qo'shish: psixolog (himoyalangan rol — direktor bera olmaydi, chunki
 * psixolog bolaning maxfiy murojaatlarini ko'radi) yoki qo'shimcha direktor.
 */

import { useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';
import { Loader2, UserPlus } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { schoolsApi, type AddSchoolStaffPayload } from '@/lib/api/admin.api';
import { cn } from '@/lib/utils';
import type { AdminSchool } from '@/types/api.types';
import type { ShownCredentials } from './credentials-dialog';
import { FormField } from './form-field';
import { LIMITS, usernameError } from './school-form';
import { schoolsErrorMessage } from './schools-errors';
import { schoolsKeys } from './schools-keys';

type Role = AddSchoolStaffPayload['role'];

const ROLE_OPTIONS: Array<{ value: Role; label: string; username: string }> = [
  { value: 'PSYCHOLOGIST', label: 'Psixolog', username: 'psixolog' },
  { value: 'DIRECTOR', label: 'Direktor', username: '' },
];

export function SchoolAddAccount({
  school,
  onCredentials,
}: {
  school: AdminSchool;
  onCredentials: (c: ShownCredentials) => void;
}) {
  const qc = useQueryClient();
  const [open, setOpen] = useState(false);
  const [role, setRole] = useState<Role>('PSYCHOLOGIST');
  const [fullName, setFullName] = useState('');
  const [username, setUsername] = useState(ROLE_OPTIONS[0].username);
  const [submitted, setSubmitted] = useState(false);

  const errors = {
    fullName: fullName.trim() ? undefined : 'F.I.Sh. kiritilmagan',
    username: usernameError(username),
  };
  const shown: Partial<typeof errors> = submitted ? errors : {};

  const reset = () => {
    setOpen(false);
    setRole('PSYCHOLOGIST');
    setFullName('');
    setUsername(ROLE_OPTIONS[0].username);
    setSubmitted(false);
  };

  const add = useMutation({
    mutationFn: () =>
      schoolsApi.addStaff(school.id, {
        role,
        fullName: fullName.trim(),
        username: username.trim().toLowerCase(),
      }),
    onSuccess: (credentials) => {
      void qc.invalidateQueries({ queryKey: schoolsKeys.all });
      reset();
      onCredentials({
        ...credentials,
        title: 'Hisob tayyor',
        schoolName: school.name,
      });
    },
    onError: (e) => toast.error(schoolsErrorMessage(e)),
  });

  if (!open) {
    return (
      <Button variant="outline" className="w-full" onClick={() => setOpen(true)}>
        <UserPlus className="h-4 w-4" /> Psixolog yoki direktor qo&apos;shish
      </Button>
    );
  }

  const submit = () => {
    setSubmitted(true);
    if (errors.fullName || errors.username) return;
    add.mutate();
  };

  return (
    <div className="space-y-4 rounded-xl border border-primary/30 p-4">
      <div role="radiogroup" aria-label="Rol" className="inline-flex rounded-lg border border-border p-1">
        {ROLE_OPTIONS.map((o) => (
          <button
            key={o.value}
            type="button"
            role="radio"
            aria-checked={role === o.value}
            onClick={() => {
              setRole(o.value);
              setUsername(o.username);
            }}
            className={cn(
              'rounded-md px-3 py-1.5 text-sm font-medium transition-colors',
              role === o.value ? 'bg-primary text-primary-foreground' : 'text-muted-foreground hover:text-foreground',
            )}
          >
            {o.label}
          </button>
        ))}
      </div>
      <FormField id="add-fullName" label="F.I.Sh." error={shown.fullName}>
        <Input
          id="add-fullName"
          value={fullName}
          maxLength={LIMITS.fullName}
          onChange={(e) => setFullName(e.target.value)}
        />
      </FormField>
      <FormField id="add-username" label="Login" error={shown.username}>
        <Input
          id="add-username"
          value={username}
          maxLength={32}
          autoCapitalize="none"
          spellCheck={false}
          className="font-mono"
          onChange={(e) => setUsername(e.target.value.toLowerCase())}
        />
      </FormField>
      <div className="flex justify-end gap-2">
        <Button variant="ghost" size="sm" onClick={reset}>
          Bekor qilish
        </Button>
        <Button size="sm" onClick={submit} disabled={add.isPending}>
          {add.isPending && <Loader2 className="h-4 w-4 animate-spin" />}
          Hisob yaratish
        </Button>
      </div>
    </div>
  );
}
