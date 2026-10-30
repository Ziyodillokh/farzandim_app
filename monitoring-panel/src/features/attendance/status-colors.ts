/**
 * Davomat holatlari ranglari (qo'shni juftliklar rang ko'rligida ham ajraladi —
 * dataviz validatori bilan tekshirilgan): o'z vaqtida — yashil, kechikish — amber,
 * erta ketish — ko'k, sababli — neytral kulrang, sababsiz — to'q amber. Qizil yo'q.
 */
export const STATUS_KEYS = ['onTime', 'late', 'leftEarly', 'excused', 'absent'] as const;
export type StatusKey = (typeof STATUS_KEYS)[number];

export const STATUS_COLORS: Record<StatusKey, string> = {
  onTime: 'hsl(160 64% 42%)',
  late: 'hsl(40 92% 54%)',
  leftEarly: 'hsl(221 90% 60%)',
  excused: 'hsl(220 22% 70%)',
  absent: 'hsl(24 90% 56%)',
};

/** Darsda bo'lganlar (davomatga kiradi) va kelmaganlar. */
export const PRESENT_KEYS: readonly StatusKey[] = ['onTime', 'late', 'leftEarly'];
export const ABSENT_KEYS: readonly StatusKey[] = ['excused', 'absent'];
