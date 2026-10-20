'use client';

import { zodResolver } from '@hookform/resolvers/zod';
import { useEffect, useRef, useState } from 'react';
import { Controller, useForm } from 'react-hook-form';

import { ROLES } from '@/auth/permissions';
import { useCan, useSession } from '@/auth/use-session';
import { FormField } from '@/components/common/form-field';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import type { RoleKey } from '@/data/contracts';
import type { StaffRow } from '@/data/mock/services/staff';
import { isHttpMode } from '@/data/source';
import { CLASS_SCOPED_ROLES, staffFormSchema, type StaffInput } from '@/data/schemas/staff';
import { useSetStaffPhoto } from '@/features/profile/hooks';
import { useI18n } from '@/i18n';
import { isProtectedRole } from '../account';
import { useCreateStaff, useUpdateStaff } from '../hooks';
import { ClassMultiSelect } from './class-multi-select';
import { StaffPhotoField } from './staff-photo-field';

type FormValues = { fullName: string; position: string; role: RoleKey; phone: string; email: string; classIds: string[] };

const EMPTY: FormValues = { fullName: '', position: '', role: 'TEACHER', phone: '+998 ', email: '', classIds: [] };
const ROLE_KEYS = Object.keys(ROLES) as RoleKey[];

function isClassScoped(role: RoleKey): boolean {
  return (CLASS_SCOPED_ROLES as readonly RoleKey[]).includes(role);
}

export function StaffFormDialog({ open, onOpenChange, row }: { open: boolean; onOpenChange: (open: boolean) => void; row?: StaffRow }) {
  const { t } = useI18n();
  const create = useCreateStaff();
  const update = useUpdateStaff();
  const setPhoto = useSetStaffPhoto();
  const canPhoto = useCan()('staff.manage');
  const form = useForm<FormValues>({ resolver: zodResolver(staffFormSchema), defaultValues: EMPTY });
  const selfId = useSession()?.staffId;
  // Demo hisoblar rolini o'zgartirib bo'lmaydi; haqiqiy rejimda — faqat o'z rolini.
  const roleLocked = isHttpMode ? Boolean(row && row.id === selfId) : Boolean(row?.username);
  // Haqiqiy rejimda himoyalangan rol (psixolog) tanlovda yo'q — uni operator beradi.
  const roleOptions = isHttpMode ? ROLE_KEYS.filter((r) => !isProtectedRole(r) || r === row?.role) : ROLE_KEYS;
  // undefined — o'zgarmagan; null — olib tashlash; satr — yangi rasm (saqlashda qo'llanadi).
  const [pendingPhoto, setPendingPhoto] = useState<string | null | undefined>(undefined);

  // Faqat ochilganda to'ldiriladi — fon yangilanishlari kiritilgan matnni o'chirmasin.
  const wasOpen = useRef(false);
  useEffect(() => {
    if (open && !wasOpen.current) {
      setPendingPhoto(undefined);
      form.reset(
        row
          ? { fullName: row.fullName, position: row.position, role: row.role, phone: row.phone, email: row.email, classIds: row.classIds }
          : EMPTY,
      );
    }
    wasOpen.current = open;
  }, [open, row, form]);

  const role = form.watch('role');
  const fullName = form.watch('fullName');
  const shownPhoto = pendingPhoto === undefined ? (row?.photo ?? null) : pendingPhoto;

  const submit = form.handleSubmit(async (values) => {
    const input: StaffInput = { ...values, classIds: isClassScoped(values.role) ? values.classIds : [] };
    let staffId: string;
    try {
      staffId = row ? (await update.mutateAsync({ id: row.id, input })).id : (await create.mutateAsync({ ...input, active: true })).id;
    } catch {
      return; // toast — hooks ichida, oyna ochiq qoladi
    }
    if (canPhoto && pendingPhoto !== undefined) {
      // Rasm xatosi alohida toast bilan ko'rsatiladi; xodim baribir saqlangan.
      await setPhoto.mutateAsync({ staffId, photo: pendingPhoto }).catch(() => undefined);
    }
    onOpenChange(false);
  });

  const { errors } = form.formState;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[92vh] overflow-y-auto sm:max-w-xl">
        <DialogHeader>
          <DialogTitle>{row ? t('staff.editTitle') : t('staff.createTitle')}</DialogTitle>
          <DialogDescription>{t(`staff.roles.desc.${role}`)}</DialogDescription>
        </DialogHeader>
        <form onSubmit={submit} className="grid gap-4" noValidate>
          {canPhoto && (
            <StaffPhotoField
              name={fullName || row?.fullName || ''}
              photo={shownPhoto}
              portrait={row?.portrait ?? null}
              pending={pendingPhoto !== undefined}
              busy={setPhoto.isPending}
              onPick={setPendingPhoto}
              onRemove={() => setPendingPhoto(null)}
            />
          )}
          <FormField label={t('staff.form.fullName')} htmlFor="staff-name" error={errors.fullName}>
            <Input id="staff-name" placeholder={t('staff.form.fullNamePlaceholder')} {...form.register('fullName')} />
          </FormField>
          <div className="grid gap-4 sm:grid-cols-2">
            <FormField label={t('staff.form.position')} htmlFor="staff-position" error={errors.position}>
              <Input id="staff-position" placeholder={t('staff.form.positionPlaceholder')} {...form.register('position')} />
            </FormField>
            <FormField label={t('staff.form.role')} error={errors.role} hint={roleLocked ? t(isHttpMode ? 'staff.form.roleLockedSelf' : 'staff.form.roleLocked') : undefined}>
              <Controller
                control={form.control}
                name="role"
                render={({ field }) => (
                  <Select value={field.value} onValueChange={field.onChange} disabled={roleLocked}>
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {roleOptions.map((r) => (
                        <SelectItem key={r} value={r}>
                          {t(`enums.role.${r}`)}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                )}
              />
            </FormField>
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <FormField label={t('staff.form.phone')} htmlFor="staff-phone" error={errors.phone} hint="+998 90 123 45 67">
              <Input id="staff-phone" inputMode="tel" {...form.register('phone')} />
            </FormField>
            <FormField label={t('staff.form.email')} htmlFor="staff-email" error={errors.email} optional>
              <Input id="staff-email" type="email" {...form.register('email')} />
            </FormField>
          </div>
          {isClassScoped(role) && (
            <FormField
              label={t('staff.form.classes')}
              error={errors.classIds}
              hint={role === 'HOMEROOM' ? t('staff.form.classesHomeroom') : t('staff.form.classesTeacher')}
            >
              <Controller
                control={form.control}
                name="classIds"
                render={({ field }) => <ClassMultiSelect value={field.value} onChange={field.onChange} invalid={Boolean(errors.classIds)} />}
              />
            </FormField>
          )}
          <DialogFooter className="mt-2">
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" loading={create.isPending || update.isPending || setPhoto.isPending}>
              {t('common.save')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
