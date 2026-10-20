'use client';

import { zodResolver } from '@hookform/resolvers/zod';
import { Building2 } from 'lucide-react';
import { useEffect } from 'react';
import { useForm } from 'react-hook-form';

import { FormField } from '@/components/common/form-field';
import { SectionCard } from '@/components/common/section-card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import type { School } from '@/data/contracts';
import { schoolProfileSchema } from '@/data/schemas/school';
import { useI18n } from '@/i18n';
import { useUpdateProfile } from '../hooks';

type FormValues = { name: string; shortName: string; city: string; address: string; phone: string; academicYear: string; lateAfterMinutes: number };

function toValues(s: School): FormValues {
  return { name: s.name, shortName: s.shortName, city: s.city, address: s.address, phone: s.phone, academicYear: s.academicYear, lateAfterMinutes: s.lateAfterMinutes };
}

export function ProfileCard({ school }: { school: School }) {
  const { t } = useI18n();
  const save = useUpdateProfile();
  const form = useForm<FormValues>({ resolver: zodResolver(schoolProfileSchema), defaultValues: toValues(school) });
  const { errors, isDirty } = form.formState;

  // Tashqi o'zgarish (boshqa tab, demo tiklash) — faqat tahrirlanmayotgan bo'lsa qo'llanadi.
  useEffect(() => {
    if (!form.formState.isDirty) form.reset(toValues(school));
  }, [school, form]);

  const submit = form.handleSubmit(async (values) => {
    try {
      const next = await save.mutateAsync(values);
      form.reset(toValues(next));
    } catch {
      // toast — hooks ichida
    }
  });

  return (
    <SectionCard icon={<Building2 />} title={t('settings.profile.title')} description={t('settings.profile.description')}>
      <form onSubmit={submit} className="grid gap-4" noValidate>
        <div className="grid gap-4 sm:grid-cols-[1fr_180px]">
          <FormField label={t('settings.profile.name')} htmlFor="school-name" error={errors.name}>
            <Input id="school-name" {...form.register('name')} />
          </FormField>
          <FormField label={t('settings.profile.shortName')} htmlFor="school-short" error={errors.shortName} hint={t('settings.profile.shortNameHint')}>
            <Input id="school-short" maxLength={12} {...form.register('shortName')} />
          </FormField>
        </div>
        <div className="grid gap-4 sm:grid-cols-2">
          <FormField label={t('settings.profile.city')} htmlFor="school-city" error={errors.city}>
            <Input id="school-city" {...form.register('city')} />
          </FormField>
          <FormField label={t('settings.profile.phone')} htmlFor="school-phone" error={errors.phone} optional>
            <Input id="school-phone" inputMode="tel" {...form.register('phone')} />
          </FormField>
        </div>
        <FormField label={t('settings.profile.address')} htmlFor="school-address" error={errors.address} optional>
          <Input id="school-address" {...form.register('address')} />
        </FormField>
        <div className="grid gap-4 sm:grid-cols-2">
          <FormField label={t('settings.profile.academicYear')} htmlFor="school-year" error={errors.academicYear}>
            <Input id="school-year" placeholder="2026–2027" {...form.register('academicYear')} />
          </FormField>
          <FormField
            label={t('settings.profile.lateAfter')}
            htmlFor="school-late"
            error={errors.lateAfterMinutes ? { message: t('settings.profile.lateRange') } : undefined}
            hint={t('settings.profile.lateAfterHint')}
          >
            <div className="relative">
              <Input id="school-late" type="number" min={0} max={60} className="pr-16" {...form.register('lateAfterMinutes', { valueAsNumber: true })} />
              <span className="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 text-sm text-muted-foreground">
                {t('settings.profile.minutes')}
              </span>
            </div>
          </FormField>
        </div>
        <div className="flex justify-end gap-2 border-t border-border/50 pt-4 dark:border-white/[0.06]">
          <Button type="button" variant="ghost" disabled={!isDirty || save.isPending} onClick={() => form.reset(toValues(school))}>
            {t('settings.profile.reset')}
          </Button>
          <Button type="submit" disabled={!isDirty} loading={save.isPending}>
            {t('common.save')}
          </Button>
        </div>
      </form>
    </SectionCard>
  );
}
