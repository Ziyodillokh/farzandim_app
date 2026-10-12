import type { api } from '@/data/api';

export type MonthReport = Awaited<ReturnType<typeof api.attendance.monthReport>>;
export type MonthReportRow = MonthReport['rows'][number];
