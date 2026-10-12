'use client';

import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';

import { api } from '@/data/api';
import type { AttendanceEventKind, AttendanceStatus, EarlyExitStatus, IsoDate } from '@/data/contracts';
import type { CorrectionInput, EarlyExitInput } from '@/data/schemas/attendance';
import { type TKey, useI18n } from '@/i18n';
import { errorKey } from '@/lib/errors';

/** Jonli ma'lumot yangilanish oralig'i (simulyator har virtual daqiqada yozadi). */
const LIVE_MS = 5_000;
const FEED_MS = 3_000;
const KIOSK_MS = 2_000;

export type FeedOptions = { classId?: string; kind?: AttendanceEventKind; limit?: number };

export const attendanceKeys = {
  all: ['attendance'] as const,
  board: (date: IsoDate | undefined) => ['attendance', 'board', date ?? 'today'] as const,
  classDay: (classId: string, date: IsoDate | undefined) => ['attendance', 'class', classId, date ?? 'today'] as const,
  feed: (options: FeedOptions) => ['attendance', 'feed', options] as const,
  notifications: ['attendance', 'notifications'] as const,
  earlyExits: (status: EarlyExitStatus | undefined) => ['attendance', 'early-exits', status ?? 'all'] as const,
  corrections: ['attendance', 'corrections'] as const,
  month: (month: string, classId: string) => ['attendance', 'month', month, classId] as const,
  classOptions: ['attendance', 'class-options'] as const,
  kioskStats: ['attendance', 'kiosk-stats'] as const,
  kioskSearch: (query: string) => ['attendance', 'kiosk-search', query] as const,
  studentSearch: (query: string) => ['attendance', 'student-search', query] as const,
};

export function useBoard(date: IsoDate | undefined) {
  return useQuery({
    queryKey: attendanceKeys.board(date),
    queryFn: () => api.attendance.board(date),
    placeholderData: keepPreviousData,
    refetchInterval: LIVE_MS,
  });
}

export function useClassDay(classId: string | null, date: IsoDate | undefined) {
  return useQuery({
    queryKey: attendanceKeys.classDay(classId ?? '', date),
    queryFn: () => api.attendance.classDay(classId ?? '', date),
    enabled: Boolean(classId),
    refetchInterval: LIVE_MS,
  });
}

export function useFeed(options: FeedOptions) {
  return useQuery({
    queryKey: attendanceKeys.feed(options),
    queryFn: () => api.attendance.feed(options),
    placeholderData: keepPreviousData,
    refetchInterval: FEED_MS,
  });
}

export function useParentNotifications(limit = 200) {
  return useQuery({
    queryKey: attendanceKeys.notifications,
    queryFn: () => api.attendance.notifications(limit),
    refetchInterval: LIVE_MS,
  });
}

export function useEarlyExits(status?: EarlyExitStatus) {
  return useQuery({ queryKey: attendanceKeys.earlyExits(status), queryFn: () => api.attendance.earlyExits(status) });
}

export function useCorrections(enabled = true) {
  return useQuery({ queryKey: attendanceKeys.corrections, queryFn: () => api.attendance.corrections(), enabled });
}

export function useMonthReport(month: string, classId: string | undefined) {
  return useQuery({
    queryKey: attendanceKeys.month(month, classId ?? ''),
    queryFn: () => api.attendance.monthReport(month, classId ?? ''),
    enabled: Boolean(classId && month),
    placeholderData: keepPreviousData,
  });
}

export function useAttendanceClassOptions() {
  return useQuery({ queryKey: attendanceKeys.classOptions, queryFn: () => api.attendance.classOptions(), staleTime: 60_000 });
}

export function useKioskStats(enabled = true) {
  return useQuery({ queryKey: attendanceKeys.kioskStats, queryFn: () => api.attendance.kioskStats(), enabled, refetchInterval: KIOSK_MS });
}

export function useKioskSearch(query: string) {
  const q = query.trim();
  return useQuery({
    queryKey: attendanceKeys.kioskSearch(q),
    queryFn: () => api.attendance.kioskSearch(q),
    enabled: q.length >= 2,
    placeholderData: keepPreviousData,
  });
}

/** Erta ketish formasidagi o'quvchi tanlovi (o'quvchilar ruxsati bilan). */
export function useStudentSearch(query: string) {
  const q = query.trim();
  return useQuery({
    queryKey: attendanceKeys.studentSearch(q),
    queryFn: () => api.students.list({ search: q, limit: 8 }),
    enabled: q.length >= 2,
    placeholderData: keepPreviousData,
  });
}

/** Davomat o'zgarishi — barcha ro'yxatlar yangilanadi, natija toast bilan. */
function useAttendanceMutation<TVars, TResult>(fn: (vars: TVars) => Promise<TResult>, successKey: TKey) {
  const queryClient = useQueryClient();
  const { t } = useI18n();
  return useMutation({
    mutationFn: fn,
    onSuccess: () => {
      void queryClient.invalidateQueries();
      toast.success(t(successKey));
    },
    onError: (error) => toast.error(t(errorKey(error))),
  });
}

export function useMarkAttendance() {
  return useAttendanceMutation(
    ({ studentId, status, reason }: { studentId: string; status: AttendanceStatus; reason?: string }) =>
      api.attendance.mark(studentId, status, reason),
    'attendance.classPage.marked',
  );
}

export function useCorrectAttendance() {
  return useAttendanceMutation((input: CorrectionInput) => api.attendance.correct(input), 'attendance.classPage.corrected');
}

export function useCreateEarlyExit() {
  return useAttendanceMutation((input: EarlyExitInput) => api.attendance.createEarlyExit(input), 'attendance.earlyExit.created');
}

export function useDecideEarlyExit() {
  const queryClient = useQueryClient();
  const { t } = useI18n();
  return useMutation({
    mutationFn: ({ id, approve }: { id: string; approve: boolean }) => api.attendance.decideEarlyExit(id, approve),
    onSuccess: (_result, { approve }) => {
      void queryClient.invalidateQueries();
      toast.success(t(approve ? 'attendance.earlyExit.approved' : 'attendance.earlyExit.rejected'));
    },
    onError: (error) => toast.error(t(errorKey(error))),
  });
}

/** Kiosk: natija ekranda katta kartochkada ko'rsatiladi (toast emas). */
export function useKioskCheckIn() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (code: string) => api.attendance.checkIn(code),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: attendanceKeys.all }),
  });
}
