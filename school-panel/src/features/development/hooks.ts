'use client';

import { keepPreviousData, useQuery } from '@tanstack/react-query';

import { api } from '@/data/api';

export const devKeys = {
  all: ['development'] as const,
  profile: (studentId: string) => ['development', 'profile', studentId] as const,
  classes: ['development', 'classes'] as const,
  classView: (classId: string, termKey: string | undefined) => ['development', 'class', classId, termKey ?? null] as const,
  school: (termKey: string | undefined) => ['development', 'school', termKey ?? null] as const,
  attention: ['development', 'attention'] as const,
  terms: ['development', 'terms'] as const,
};

export function useDevProfile(studentId: string) {
  return useQuery({ queryKey: devKeys.profile(studentId), queryFn: () => api.development.studentProfile(studentId), enabled: Boolean(studentId) });
}

export function useDevClassOptions(enabled = true) {
  return useQuery({ queryKey: devKeys.classes, queryFn: () => api.development.classOptions(), enabled });
}

export function useDevClass(classId: string | undefined, termKey: string | undefined) {
  return useQuery({
    queryKey: devKeys.classView(classId ?? '', termKey),
    queryFn: () => api.development.classOverview(classId ?? '', termKey),
    placeholderData: keepPreviousData,
    enabled: Boolean(classId),
  });
}

export function useDevSchool(termKey: string | undefined, enabled = true) {
  return useQuery({
    queryKey: devKeys.school(termKey),
    queryFn: () => api.development.schoolOverview(termKey ? { termKey } : {}),
    placeholderData: keepPreviousData,
    enabled,
  });
}

export function useDevAttention(enabled = true) {
  return useQuery({ queryKey: devKeys.attention, queryFn: () => api.development.attentionList(), enabled });
}

export function useDevTerms(enabled = true) {
  return useQuery({ queryKey: devKeys.terms, queryFn: () => api.development.termOptions(), enabled });
}
