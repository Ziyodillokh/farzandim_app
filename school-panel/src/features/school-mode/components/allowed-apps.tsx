'use client';

import { zodResolver } from '@hookform/resolvers/zod';
import { Plus, Smartphone, X } from 'lucide-react';
import { Controller, useForm } from 'react-hook-form';

import { Can } from '@/auth/can';
import { EmptyState } from '@/components/common/empty-state';
import { FormField } from '@/components/common/form-field';
import { SectionCard } from '@/components/common/section-card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import type { AllowedApp } from '@/data/contracts';
import { allowedAppSchema, APP_CATEGORIES, type AllowedAppInput } from '@/data/schemas/school-mode';
import { useI18n } from '@/i18n';
import { useAddAllowedApp, useRemoveAllowedApp } from '../hooks';
import { CATEGORY_ICONS } from './policy-settings';

function AddAppForm() {
  const { t } = useI18n();
  const add = useAddAllowedApp();
  const form = useForm<AllowedAppInput>({ resolver: zodResolver(allowedAppSchema), defaultValues: { name: '', category: 'EDU' } });
  const submit = form.handleSubmit((values) => add.mutate(values, { onSuccess: () => form.reset({ name: '', category: values.category }) }));
  return (
    <form onSubmit={submit} className="mt-4 grid gap-3 border-t pt-4 sm:grid-cols-[1fr_11rem_auto] sm:items-start" noValidate>
      <FormField label={t('schoolMode.policies.appName')} htmlFor="app-name" error={form.formState.errors.name}>
        <Input id="app-name" placeholder={t('schoolMode.policies.appNamePlaceholder')} {...form.register('name')} />
      </FormField>
      <FormField label={t('schoolMode.policies.appCategory')}>
        <Controller
          control={form.control}
          name="category"
          render={({ field }) => (
            <Select value={field.value} onValueChange={field.onChange}>
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {APP_CATEGORIES.map((c) => (
                  <SelectItem key={c} value={c}>
                    {t(`enums.appCategory.${c}`)}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          )}
        />
      </FormField>
      <Button type="submit" loading={add.isPending} className="sm:mt-[1.6rem]">
        <Plus />
        {t('schoolMode.policies.addApp')}
      </Button>
    </form>
  );
}

/** Maktab tasdiqlagan ilovalar — dars vaqtida ham ochiq. */
export function AllowedApps({ apps, canManage }: { apps: AllowedApp[]; canManage: boolean }) {
  const { t } = useI18n();
  const remove = useRemoveAllowedApp();
  return (
    <SectionCard title={t('schoolMode.policies.apps')} description={t('schoolMode.policies.appsHint')}>
      {apps.length === 0 ? (
        <EmptyState icon={<Smartphone />} title={t('schoolMode.policies.noApps')} className="py-8" />
      ) : (
        <ul className="grid gap-2 sm:grid-cols-2">
          {apps.map((app) => {
            const Icon = CATEGORY_ICONS[app.category];
            const removing = remove.isPending && remove.variables === app.id;
            return (
              <li key={app.id} className="flex items-center gap-3 rounded-xl border bg-card px-3 py-2.5 animate-fade-in">
                <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-primary/10 text-primary">
                  <Icon className="h-4 w-4" aria-hidden />
                </span>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-medium">{app.name}</p>
                  <p className="text-xs text-muted-foreground">{t(`enums.appCategory.${app.category}`)}</p>
                </div>
                {canManage && (
                  <Button variant="ghost" size="icon-sm" onClick={() => remove.mutate(app.id)} loading={removing} aria-label={`${t('common.delete')}: ${app.name}`}>
                    {!removing && <X />}
                  </Button>
                )}
              </li>
            );
          })}
        </ul>
      )}
      <Can perm="schoolMode.manage">
        <AddAppForm />
      </Can>
    </SectionCard>
  );
}
