'use client';

import { Search, X } from 'lucide-react';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import {
  KELAJAK_AGE_GROUPS,
  KELAJAK_ANSWER_TYPES,
  KELAJAK_CATEGORIES,
  KELAJAK_SOURCE_TYPES,
} from '@/lib/constants/kelajak';
import type { KelajakListParams } from '@/lib/api/admin.api';
import { FilterSelect, type FilterOption } from './filter-select';

export interface KelajakFilterValues {
  category: string;
  ageGroup: string;
  /** '' — hammasi. */
  status: '' | 'active' | 'inactive';
  answerType: string;
  sourceType: string;
}

export const EMPTY_FILTERS: KelajakFilterValues = {
  category: '',
  ageGroup: '',
  status: '',
  answerType: '',
  sourceType: '',
};

const withAll = (allLabel: string, list: ReadonlyArray<FilterOption>): FilterOption[] => [
  { value: '', label: allLabel },
  ...list,
];

const CATEGORY_FILTERS = withAll('Barcha kategoriyalar', KELAJAK_CATEGORIES);
const AGE_FILTERS = withAll('Barcha yoshlar', KELAJAK_AGE_GROUPS);
const ANSWER_TYPE_FILTERS = withAll('Barcha javob turlari', KELAJAK_ANSWER_TYPES);
const SOURCE_FILTERS = withAll('Barcha manbalar', KELAJAK_SOURCE_TYPES);
const STATUS_FILTERS: FilterOption[] = [
  { value: '', label: 'Barcha holatlar' },
  { value: 'active', label: 'Faol' },
  { value: 'inactive', label: 'Nofaol' },
];

/**
 * Filtrlardan API parametrlari. Bo'sh qiymatlar yuborilmaydi — backend
 * `@IsIn` bo'sh satrni rad etadi.
 */
export function toListParams(
  filters: KelajakFilterValues,
  q: string,
  page: number,
  limit: number,
): KelajakListParams {
  return {
    page,
    limit,
    ...(filters.category ? { category: filters.category } : {}),
    ...(filters.ageGroup ? { ageGroup: filters.ageGroup } : {}),
    ...(filters.answerType ? { answerType: filters.answerType } : {}),
    ...(filters.sourceType ? { sourceType: filters.sourceType } : {}),
    ...(filters.status ? { active: filters.status === 'active' ? 'true' : 'false' } : {}),
    ...(q ? { q } : {}),
  };
}

export function KelajakFilters({
  values,
  onChange,
  search,
  onSearchChange,
  onReset,
}: {
  values: KelajakFilterValues;
  onChange: <K extends keyof KelajakFilterValues>(key: K, value: KelajakFilterValues[K]) => void;
  search: string;
  onSearchChange: (v: string) => void;
  onReset: () => void;
}) {
  const isFiltered =
    search.trim() !== '' || Object.values(values).some((v) => v !== '');

  return (
    <Card className="mb-4 p-4">
      <div className="flex flex-wrap items-center gap-3">
        <div className="w-full min-w-0 sm:min-w-[240px] sm:flex-1">
          <Input
            icon={<Search />}
            placeholder="Savol matni yoki ID..."
            value={search}
            onChange={(e) => onSearchChange(e.target.value)}
            maxLength={100}
            aria-label="Qidiruv"
          />
        </div>
        <FilterSelect
          ariaLabel="Kategoriya"
          value={values.category}
          onChange={(v) => onChange('category', v)}
          options={CATEGORY_FILTERS}
        />
        <FilterSelect
          ariaLabel="Yosh guruhi"
          value={values.ageGroup}
          onChange={(v) => onChange('ageGroup', v)}
          options={AGE_FILTERS}
        />
        <FilterSelect
          ariaLabel="Holat"
          value={values.status}
          onChange={(v) => onChange('status', v as KelajakFilterValues['status'])}
          options={STATUS_FILTERS}
        />
        <FilterSelect
          ariaLabel="Javob turi"
          value={values.answerType}
          onChange={(v) => onChange('answerType', v)}
          options={ANSWER_TYPE_FILTERS}
        />
        <FilterSelect
          ariaLabel="Manba"
          value={values.sourceType}
          onChange={(v) => onChange('sourceType', v)}
          options={SOURCE_FILTERS}
        />
        {isFiltered && (
          <Button variant="ghost" onClick={onReset} className="w-full sm:w-auto">
            <X /> Tozalash
          </Button>
        )}
      </div>
    </Card>
  );
}
