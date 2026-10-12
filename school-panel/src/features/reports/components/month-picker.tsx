'use client';

import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { useI18n } from '@/i18n';

export function MonthPicker({ months, value, onChange }: { months: string[]; value: string; onChange: (month: string) => void }) {
  const { formatDate } = useI18n();
  const label = (m: string) => {
    const text = formatDate(`${m}-15T12:00:00`, 'LLLL yyyy');
    return text.charAt(0).toUpperCase() + text.slice(1);
  };
  return (
    <Select value={value} onValueChange={onChange}>
      <SelectTrigger className="w-48">
        <SelectValue />
      </SelectTrigger>
      <SelectContent>
        {months.map((m) => (
          <SelectItem key={m} value={m}>
            {label(m)}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  );
}
