'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';

import { api } from '@/data/api';
import type { TimetableLesson } from '@/data/contracts';

export const timetableKeys = {
  all: ['timetable'] as const,
  classes: ['timetable', 'classes'] as const,
  detail: (classId: string) => ['timetable', 'class', classId] as const,
};

/** Sinf tanlagich uchun doiradagi sinflar (sinf rahbari — faqat o'z sinfi, servisda cheklangan). */
export function useTimetableClasses() {
  return useQuery({ queryKey: timetableKeys.classes, queryFn: () => api.classes.list(), staleTime: 60_000 });
}

export function useTimetable(classId: string | null) {
  return useQuery({
    queryKey: timetableKeys.detail(classId ?? ''),
    queryFn: () => api.timetable.get(classId ?? ''),
    enabled: Boolean(classId),
  });
}

/**
 * Haftani to'liq almashtirish. Javob tanasiga tayanmaymiz — muvaffaqiyatda so'rovlar yangilanadi.
 * Xatolar (jumladan 400 → katakchalar) chaqiruvchida qayta ishlanadi.
 */
export function useSaveTimetable(classId: string | null) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (lessons: TimetableLesson[]) => api.timetable.save(classId ?? '', { lessons }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: timetableKeys.all }),
  });
}
