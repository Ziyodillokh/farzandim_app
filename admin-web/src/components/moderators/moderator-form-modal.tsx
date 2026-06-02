'use client';

import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { Sparkles } from 'lucide-react';
import { toast } from 'sonner';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Checkbox } from '@/components/ui/checkbox';
import {
  Select,
  SelectTrigger,
  SelectValue,
  SelectContent,
  SelectItem,
} from '@/components/ui/select';
import { moderatorsApi } from '@/lib/api/admin.api';
import { getApiErrorMessage } from '@/lib/api/client';
import {
  MODERATOR_ROLES,
  PERMISSION_GROUPS,
  ROLE_PRESETS,
  ALL_PERMISSION_KEYS,
} from '@/lib/constants/permissions';

interface ModeratorFormModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSuccess?: () => void;
}

function generatePassword(length = 12): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%';
  let out = '';
  for (let i = 0; i < length; i += 1) {
    out += chars[Math.floor(Math.random() * chars.length)];
  }
  return out;
}

const DEFAULT_ROLE = 'support';

export function ModeratorFormModal({ open, onOpenChange, onSuccess }: ModeratorFormModalProps) {
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [phone, setPhone] = useState('+998');
  const [password, setPassword] = useState('');
  const [role, setRole] = useState<string>(DEFAULT_ROLE);
  const [permissions, setPermissions] = useState<Set<string>>(
    () => new Set(ROLE_PRESETS[DEFAULT_ROLE] ?? []),
  );

  const isSuperAdmin = role === 'super_admin';

  const reset = () => {
    setName('');
    setEmail('');
    setPhone('+998');
    setPassword('');
    setRole(DEFAULT_ROLE);
    setPermissions(new Set(ROLE_PRESETS[DEFAULT_ROLE] ?? []));
  };

  const handleRoleChange = (value: string) => {
    setRole(value);
    setPermissions(new Set(ROLE_PRESETS[value] ?? []));
  };

  const togglePermission = (key: string) => {
    setPermissions((prev) => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      return next;
    });
  };

  const mutation = useMutation({
    mutationFn: () =>
      moderatorsApi.create({
        name: name.trim(),
        email: email.trim(),
        phone: phone.trim() || undefined,
        moderatorRoleKey: role,
        password,
        permissions: isSuperAdmin ? ALL_PERMISSION_KEYS : Array.from(permissions),
      }),
    onSuccess: () => {
      toast.success('Moderator yaratildi');
      onSuccess?.();
      reset();
      onOpenChange(false);
    },
    onError: (e) => toast.error(getApiErrorMessage(e)),
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) {
      toast.error('Ism kiritilishi shart');
      return;
    }
    if (!email.trim()) {
      toast.error('Email kiritilishi shart');
      return;
    }
    if (password.length < 8) {
      toast.error("Parol kamida 8 ta belgidan iborat bo'lishi kerak");
      return;
    }
    mutation.mutate();
  };

  return (
    <Dialog
      open={open}
      onOpenChange={(o) => {
        if (!o && !mutation.isPending) reset();
        onOpenChange(o);
      }}
    >
      <DialogContent className="max-w-2xl">
        <DialogHeader>
          <DialogTitle>Yangi moderator</DialogTitle>
          <DialogDescription>
            Moderator ma&apos;lumotlarini kiriting va ruxsatlarni tanlang.
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-5">
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <Label htmlFor="mod-name">Ism *</Label>
              <Input
                id="mod-name"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="Ism Familiya"
                required
              />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="mod-email">Email *</Label>
              <Input
                id="mod-email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="email@farzandim.uz"
                required
              />
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <Label htmlFor="mod-phone">Telefon</Label>
              <Input
                id="mod-phone"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                placeholder="+998901234567"
              />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="mod-password">Parol *</Label>
              <div className="flex gap-2">
                <Input
                  id="mod-password"
                  type="text"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="Kamida 8 ta belgi"
                  minLength={8}
                  required
                />
                <Button
                  type="button"
                  variant="outline"
                  className="shrink-0"
                  onClick={() => setPassword(generatePassword())}
                >
                  Generatsiya
                </Button>
              </div>
            </div>
          </div>

          <div className="space-y-1.5">
            <Label>Rol</Label>
            <Select value={role} onValueChange={handleRoleChange}>
              <SelectTrigger>
                <SelectValue placeholder="Rolni tanlang" />
              </SelectTrigger>
              <SelectContent>
                {MODERATOR_ROLES.map((r) => (
                  <SelectItem key={r.value} value={r.value}>
                    {r.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <Label>Ruxsatlar</Label>
              {isSuperAdmin && (
                <span className="inline-flex items-center gap-1 text-xs font-medium text-primary">
                  <Sparkles className="h-3.5 w-3.5" /> To&apos;liq ruxsat
                </span>
              )}
            </div>
            <div className="max-h-72 space-y-4 overflow-y-auto rounded-lg border border-border bg-muted/20 p-4">
              {PERMISSION_GROUPS.map((grp) => (
                <div key={grp.group} className="space-y-2">
                  <p className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                    {grp.group}
                  </p>
                  <div className="grid grid-cols-2 gap-2">
                    {grp.permissions.map((perm) => {
                      const checked = isSuperAdmin || permissions.has(perm.key);
                      return (
                        <label
                          key={perm.key}
                          htmlFor={`perm-${perm.key}`}
                          className="flex cursor-pointer items-center gap-2 text-sm"
                        >
                          <Checkbox
                            id={`perm-${perm.key}`}
                            checked={checked}
                            disabled={isSuperAdmin}
                            onCheckedChange={() => togglePermission(perm.key)}
                          />
                          <span className="text-foreground/90">{perm.label}</span>
                        </label>
                      );
                    })}
                  </div>
                </div>
              ))}
            </div>
          </div>

          <DialogFooter className="gap-2">
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
              disabled={mutation.isPending}
            >
              Bekor qilish
            </Button>
            <Button type="submit" loading={mutation.isPending}>
              Yaratish
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
