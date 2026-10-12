import type { AuditLog } from '@/data/contracts';
import { hasKey, type TKey, translate } from '@/i18n/translate';
import type { Vars } from '@/i18n/types';

type Translate = (key: TKey, vars?: Vars) => string;

/** Maxsus parametr: bir amalning bir nechta ko'rinishi (`audit.actions.<action>_<variant>`). */
const VARIANT_PARAM = 'variant';

/** Kod qiymatli parametrlar — tarjima qilinadigan enum nomlar maydoni. */
const ENUM_PARAMS: Readonly<Record<string, string>> = {
  status: 'enums.attendanceStatus',
  from: 'enums.attendanceStatus',
  to: 'enums.attendanceStatus',
  role: 'enums.role',
};

const PLACEHOLDER = /\{(\w+)\}/g;

/** `student.note.add` → `audit.actions.student_note_add` (+ `_<variant>`). */
export function auditActionKey(entry: Pick<AuditLog, 'action' | 'params'>): string {
  const base = `audit.actions.${entry.action.replace(/\./g, '_')}`;
  const variant = entry.params?.[VARIANT_PARAM];
  return variant === undefined || variant === '' ? base : `${base}_${variant}`;
}

/** Shablondagi barcha `{x}` parametrlarda bormi (yo'q bo'lsa — eski yozuv, tavsif ko'rsatiladi). */
function placeholdersSatisfied(key: string, vars: Vars): boolean {
  const template = translate('uz', key);
  return [...template.matchAll(PLACEHOLDER)].every((m) => (m[1] ?? '') in vars);
}

function localizeVars(t: Translate, params: Vars): Vars {
  return Object.fromEntries(
    Object.entries(params)
      .filter(([name]) => name !== VARIANT_PARAM)
      .map(([name, value]) => {
        const ns = ENUM_PARAMS[name];
        const enumKey = ns ? `${ns}.${value}` : '';
        return [name, enumKey && hasKey('uz', enumKey) ? t(enumKey as TKey) : value];
      }),
  );
}

/**
 * Audit yozuvi matni joriy tilda: `audit.actions.<action>` kaliti va `params` bo'lsa —
 * tarjima, aks holda (eski yozuvlar, care/demo) saqlangan `summary`.
 */
export function auditText(t: Translate, entry: Pick<AuditLog, 'action' | 'summary' | 'params'>): string {
  const key = auditActionKey(entry);
  if (!hasKey('uz', key)) return entry.summary;
  const vars = localizeVars(t, entry.params ?? {});
  if (!placeholdersSatisfied(key, vars)) return entry.summary;
  return t(key as TKey, vars);
}
