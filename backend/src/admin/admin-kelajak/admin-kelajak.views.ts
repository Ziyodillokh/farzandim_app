// Admin Kelajak ko'rinishlari — docs/KELAJAK-REJA.md §6 (`AdminQuestionView`,
// statistika). admin-web shu shakllarga tayanadi.

import { KelajakQuestion } from '@prisma/client';
import { KELAJAK_AGE_GROUPS } from '../../modules/kelajak/domain/age';
import { KELAJAK_ANSWER_TYPES, KELAJAK_CATEGORY_IDS } from '../../modules/kelajak/domain/catalog';
import { L } from '../../modules/kelajak/domain/localized';
import { categoryName } from '../../modules/kelajak/kelajak.mapper';

export interface AdminQuestionView {
  id: string;
  externalId: string;
  category: string;
  categoryName: L;
  ageGroup: string;
  text: L;
  answerType: string;
  options: Array<{ value: number; label: L }>;
  scoring: Record<string, unknown> | null;
  reverse: boolean;
  required: boolean;
  followUp: string | null;
  notes: string | null;
  reviewNote: string | null;
  sourceType: string;
  sourceName: string;
  sourceVersion: string;
  active: boolean;
  answerCount: number;
  createdAt: Date;
  updatedAt: Date;
}

export interface CountRow {
  total: number;
  active: number;
}

export interface AdminKelajakStatsView {
  total: number;
  active: number;
  inactive: number;
  needsReview: number;
  byCategory: Array<{ category: string; name: L } & CountRow>;
  byAgeGroup: Array<{ ageGroup: string } & CountRow>;
  byAnswerType: Array<{ answerType: string } & CountRow>;
  sessions: { total: number; completed: number; completedLast7Days: number };
}

/** `groupBy([key, active])` qatori. */
export interface ActiveGroup {
  key: string;
  active: boolean;
  count: number;
}

export function toAdminQuestionView(q: KelajakQuestion, answerCount: number): AdminQuestionView {
  return {
    id: q.id,
    externalId: q.externalId,
    category: q.category,
    categoryName: categoryName(q.category),
    ageGroup: q.ageGroup,
    text: q.text as L,
    answerType: q.answerType,
    options: q.options as unknown as AdminQuestionView['options'],
    scoring: (q.scoring as Record<string, unknown> | null) ?? null,
    reverse: q.reverse,
    required: q.required,
    followUp: q.followUp,
    notes: q.notes,
    reviewNote: q.reviewNote,
    sourceType: q.sourceType,
    sourceName: q.sourceName,
    sourceVersion: q.sourceVersion,
    active: q.active,
    answerCount,
    createdAt: q.createdAt,
    updatedAt: q.updatedAt,
  };
}

/**
 * Katalog tartibida (nol bo'lsa ham) jami / faol soni; katalogda yo'q qiymat
 * (qo'lda SQL bilan yozilgan bo'lsa) oxirida — yig'indilar `total`ga teng qoladi.
 */
export function countByKey(known: readonly string[], groups: readonly ActiveGroup[]): Array<{ key: string } & CountRow> {
  const extra = [...new Set(groups.map((g) => g.key).filter((key) => !known.includes(key)))].sort();
  return [...known, ...extra].map((key) => {
    const rows = groups.filter((g) => g.key === key);
    return {
      key,
      total: rows.reduce((sum, g) => sum + g.count, 0),
      active: rows.filter((g) => g.active).reduce((sum, g) => sum + g.count, 0),
    };
  });
}

export function toStatsView(input: {
  byCategory: readonly ActiveGroup[];
  byAgeGroup: readonly ActiveGroup[];
  byAnswerType: readonly ActiveGroup[];
  needsReview: number;
  sessions: AdminKelajakStatsView['sessions'];
}): AdminKelajakStatsView {
  const categories = countByKey(KELAJAK_CATEGORY_IDS, input.byCategory);
  const total = categories.reduce((sum, c) => sum + c.total, 0);
  const active = categories.reduce((sum, c) => sum + c.active, 0);
  return {
    total,
    active,
    inactive: total - active,
    needsReview: input.needsReview,
    byCategory: categories.map(({ key, ...counts }) => ({ category: key, name: categoryName(key), ...counts })),
    byAgeGroup: countByKey(KELAJAK_AGE_GROUPS, input.byAgeGroup).map(({ key, ...counts }) => ({
      ageGroup: key,
      ...counts,
    })),
    byAnswerType: countByKey(KELAJAK_ANSWER_TYPES, input.byAnswerType).map(({ key, ...counts }) => ({
      answerType: key,
      ...counts,
    })),
    sessions: input.sessions,
  };
}
