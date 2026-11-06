'use client';

import { CalendarClock, Timer, UserRoundCog } from 'lucide-react';

import { FormField } from '@/components/common/form-field';
import { SectionCard } from '@/components/common/section-card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import type { CareStaffOption } from '@/data/contracts';
import { CARE_SETTINGS_LIMITS } from '@/data/schemas/care';
import { useI18n } from '@/i18n';
import { NO_STAFF, type SettingsDraft } from '../lib/settings';
import { WorkDaysPicker } from './work-days-picker';

export type SettingsErrors = Partial<Record<keyof SettingsDraft, string>>;

export type SectionProps = {
  draft: SettingsDraft;
  onChange: (patch: Partial<SettingsDraft>) => void;
  errors: SettingsErrors;
  disabled: boolean;
};

const fieldId = (name: keyof SettingsDraft) => `care-settings-${name}`;

function StaffSelect({
  name,
  label,
  value,
  options,
  disabledId,
  onChange,
  error,
  disabled,
}: {
  name: keyof SettingsDraft;
  label: string;
  value: string;
  options: readonly CareStaffOption[];
  /** Boshqa maydonda tanlangan xodim — bu ro'yxatda o'chirib qo'yiladi. */
  disabledId?: string;
  onChange: (value: string) => void;
  error?: string;
  disabled: boolean;
}) {
  const { t } = useI18n();
  return (
    <FormField label={label} htmlFor={fieldId(name)} error={{ message: error }}>
      <Select value={value} onValueChange={onChange} disabled={disabled}>
        <SelectTrigger id={fieldId(name)} aria-invalid={Boolean(error) || undefined} aria-label={label}>
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value={NO_STAFF}>{t('care.settings.none')}</SelectItem>
          {options.map((o) => (
            <SelectItem key={o.id} value={o.id} disabled={o.id === disabledId}>
              {o.fullName}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </FormField>
  );
}

function DisplayNameInput({
  name,
  value,
  onChange,
  error,
  disabled,
  owner,
  showHint,
}: {
  name: keyof SettingsDraft;
  value: string;
  onChange: (value: string) => void;
  error?: string;
  disabled: boolean;
  /** Kimning ismi (ekran o'qiydigan to'liq nom uchun: «Masʼul psixolog: bolaga koʻrinadigan ism»). */
  owner: string;
  showHint: boolean;
}) {
  const { t } = useI18n();
  return (
    <FormField label={t('care.settings.displayName')} htmlFor={fieldId(name)} error={{ message: error }} hint={showHint ? t('care.settings.displayNameHint') : undefined} optional>
      <Input
        id={fieldId(name)}
        aria-label={`${owner}: ${t('care.settings.displayName').toLowerCase()}`}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        maxLength={CARE_SETTINGS_LIMITS.displayName}
        placeholder={t('care.settings.displayNamePlaceholder')}
        disabled={disabled}
        aria-invalid={Boolean(error) || undefined}
        autoComplete="off"
      />
    </FormField>
  );
}

/** Mas'ul psixolog va o'rinbosar + bolaga ko'rinadigan ismlar. */
export function StaffSection({ draft, onChange, errors, disabled, options }: SectionProps & { options: readonly CareStaffOption[] }) {
  const { t } = useI18n();
  return (
    <SectionCard title={t('care.settings.staffTitle')} description={t('care.settings.staffHint')} icon={<UserRoundCog />}>
      {options.length === 0 ? (
        <p className="mb-4 rounded-xl bg-warning/10 px-3 py-2 text-sm text-warning ring-1 ring-inset ring-warning/20" role="status">
          {t('care.settings.noPsychologists')}
        </p>
      ) : null}
      <div className="grid gap-x-5 gap-y-4 md:grid-cols-2">
        <StaffSelect
          name="psychologistStaffId"
          label={t('care.settings.psychologist')}
          value={draft.psychologistStaffId}
          options={options}
          disabledId={draft.deputyStaffId}
          onChange={(v) => onChange({ psychologistStaffId: v })}
          error={errors.psychologistStaffId}
          disabled={disabled}
        />
        <DisplayNameInput
          name="psychologistDisplayName"
          owner={t('care.settings.psychologist')}
          showHint
          value={draft.psychologistDisplayName}
          onChange={(v) => onChange({ psychologistDisplayName: v })}
          error={errors.psychologistDisplayName}
          disabled={disabled}
        />
        <StaffSelect
          name="deputyStaffId"
          label={t('care.settings.deputy')}
          value={draft.deputyStaffId}
          options={options}
          disabledId={draft.psychologistStaffId}
          onChange={(v) => onChange({ deputyStaffId: v })}
          error={errors.deputyStaffId}
          disabled={disabled}
        />
        <DisplayNameInput
          name="deputyDisplayName"
          owner={t('care.settings.deputy')}
          showHint={false}
          value={draft.deputyDisplayName}
          onChange={(v) => onChange({ deputyDisplayName: v })}
          error={errors.deputyDisplayName}
          disabled={disabled}
        />
      </div>
      {draft.deputyStaffId === NO_STAFF && (
        <p className="mt-4 text-xs text-muted-foreground" role="note">
          {t('care.settings.noDeputy')}
        </p>
      )}
    </SectionCard>
  );
}

/** Ish kunlari va soatlari. */
export function HoursSection({ draft, onChange, errors, disabled }: SectionProps) {
  const { t } = useI18n();
  const labelId = 'care-settings-workDays-label';
  return (
    <SectionCard title={t('care.settings.hoursTitle')} description={t('care.settings.hoursHint')} icon={<CalendarClock />}>
      <div className="space-y-4">
        <div className="space-y-1.5">
          <Label id={labelId}>{t('care.settings.workDays')}</Label>
          <WorkDaysPicker
            id={fieldId('workDays')}
            labelledBy={labelId}
            value={draft.workDays}
            onChange={(workDays) => onChange({ workDays })}
            disabled={disabled}
            invalid={Boolean(errors.workDays)}
          />
          {errors.workDays && <p className="text-xs font-medium text-destructive">{errors.workDays}</p>}
        </div>
        <div className="grid gap-x-5 gap-y-4 sm:grid-cols-2">
          <FormField label={t('care.settings.workStart')} htmlFor={fieldId('workStart')} error={{ message: errors.workStart }}>
            <Input id={fieldId('workStart')} type="time" value={draft.workStart} onChange={(e) => onChange({ workStart: e.target.value })} disabled={disabled} aria-invalid={Boolean(errors.workStart) || undefined} />
          </FormField>
          <FormField label={t('care.settings.workEnd')} htmlFor={fieldId('workEnd')} error={{ message: errors.workEnd }}>
            <Input id={fieldId('workEnd')} type="time" value={draft.workEnd} onChange={(e) => onChange({ workEnd: e.target.value })} disabled={disabled} aria-invalid={Boolean(errors.workEnd) || undefined} />
          </FormField>
        </div>
      </div>
    </SectionCard>
  );
}

function NumberField({
  name,
  label,
  hint,
  value,
  min,
  max,
  onChange,
  error,
  disabled,
}: {
  name: keyof SettingsDraft;
  label: string;
  hint: string;
  value: string;
  min: number;
  max: number;
  onChange: (value: string) => void;
  error?: string;
  disabled: boolean;
}) {
  return (
    <FormField label={label} htmlFor={fieldId(name)} error={{ message: error }} hint={hint}>
      <Input
        id={fieldId(name)}
        type="number"
        inputMode="numeric"
        min={min}
        max={max}
        step={1}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        disabled={disabled}
        aria-invalid={Boolean(error) || undefined}
      />
    </FormField>
  );
}

/** Javob muddati (ish vaqti hisobida). */
export function SlaSection({ draft, onChange, errors, disabled }: SectionProps) {
  const { t } = useI18n();
  const minutes = CARE_SETTINGS_LIMITS.urgentSlaMinutes;
  const hours = CARE_SETTINGS_LIMITS.normalSlaHours;
  return (
    <SectionCard title={t('care.settings.slaTitle')} description={t('care.settings.slaHint')} icon={<Timer />}>
      <div className="grid gap-x-5 gap-y-4 sm:grid-cols-2">
        <NumberField
          name="urgentSlaMinutes"
          label={t('care.settings.urgentSla')}
          hint={t('care.settings.urgentSlaHint', { min: minutes.min, max: minutes.max })}
          value={draft.urgentSlaMinutes}
          min={minutes.min}
          max={minutes.max}
          onChange={(v) => onChange({ urgentSlaMinutes: v })}
          error={errors.urgentSlaMinutes}
          disabled={disabled}
        />
        <NumberField
          name="normalSlaHours"
          label={t('care.settings.normalSla')}
          hint={t('care.settings.normalSlaHint', { min: hours.min, max: hours.max })}
          value={draft.normalSlaHours}
          min={hours.min}
          max={hours.max}
          onChange={(v) => onChange({ normalSlaHours: v })}
          error={errors.normalSlaHours}
          disabled={disabled}
        />
      </div>
    </SectionCard>
  );
}
