'use client';

import { Plus, RotateCcw, Trash2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { KELAJAK_LIMITS, TEXT_ANSWER_TYPE } from '@/lib/constants/kelajak';
import { newOption, presetOptions, type OptionDraft, type TextDraft } from './question-form';

/** Javob variantlari: qiymat + yorliq (uz majburiy, ru/en ixtiyoriy). */
export function OptionsEditor({
  answerType,
  options,
  onChange,
  disabled,
}: {
  answerType: string;
  options: OptionDraft[];
  onChange: (options: OptionDraft[]) => void;
  disabled: boolean;
}) {
  if (answerType === TEXT_ANSWER_TYPE) {
    return (
      <p className="rounded-lg border border-dashed border-border px-3 py-4 text-sm text-muted-foreground">
        Ochiq javobli savolda variant bo&apos;lmaydi — bola o&apos;z fikrini yozadi.
      </p>
    );
  }

  const update = (index: number, patch: Partial<OptionDraft>) =>
    onChange(options.map((o, i) => (i === index ? { ...o, ...patch } : o)));

  const updateLabel = (index: number, lang: keyof TextDraft, value: string) => {
    const current = options[index];
    if (!current) return;
    update(index, { label: { ...current.label, [lang]: value } });
  };

  const remove = (index: number) => onChange(options.filter((_, i) => i !== index));
  const add = () => onChange([...options, newOption(options)]);
  const reset = () => onChange(presetOptions(answerType));

  return (
    <div className="space-y-2">
      {options.map((o, i) => (
        <div key={o.key} className="rounded-lg border border-border bg-muted/20 p-3">
          <div className="flex items-start gap-2">
            <Input
              type="number"
              step={1}
              inputMode="numeric"
              value={o.value}
              onChange={(e) => update(i, { value: e.target.value })}
              disabled={disabled}
              className="w-20 shrink-0 tabular-nums"
              aria-label={`${i + 1}-variant qiymati`}
            />
            <Input
              value={o.label.uz}
              onChange={(e) => updateLabel(i, 'uz', e.target.value)}
              disabled={disabled}
              maxLength={KELAJAK_LIMITS.optionLabelMax}
              placeholder="Yorliq (o'zbekcha)"
              aria-label={`${i + 1}-variant yorlig'i (o'zbekcha)`}
            />
            <Button
              type="button"
              variant="ghost"
              size="icon"
              onClick={() => remove(i)}
              disabled={disabled || options.length <= KELAJAK_LIMITS.optionsMin}
              aria-label={`${i + 1}-variantni o'chirish`}
              className="shrink-0 text-muted-foreground hover:text-destructive"
            >
              <Trash2 />
            </Button>
          </div>
          <div className="mt-2 grid grid-cols-1 gap-2 sm:grid-cols-2">
            <Input
              value={o.label.ru}
              onChange={(e) => updateLabel(i, 'ru', e.target.value)}
              disabled={disabled}
              maxLength={KELAJAK_LIMITS.optionLabelMax}
              placeholder="Ruscha (ixtiyoriy)"
              aria-label={`${i + 1}-variant yorlig'i (ruscha)`}
            />
            <Input
              value={o.label.en}
              onChange={(e) => updateLabel(i, 'en', e.target.value)}
              disabled={disabled}
              maxLength={KELAJAK_LIMITS.optionLabelMax}
              placeholder="Inglizcha (ixtiyoriy)"
              aria-label={`${i + 1}-variant yorlig'i (inglizcha)`}
            />
          </div>
        </div>
      ))}

      <div className="flex flex-wrap gap-2">
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={add}
          disabled={disabled || options.length >= KELAJAK_LIMITS.optionsMax}
        >
          <Plus /> Variant qo&apos;shish
        </Button>
        <Button type="button" variant="ghost" size="sm" onClick={reset} disabled={disabled}>
          <RotateCcw /> Standart variantlar
        </Button>
      </div>
    </div>
  );
}
