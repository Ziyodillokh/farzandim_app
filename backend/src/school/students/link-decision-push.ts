// Ulanish so'rovi bo'yicha xodim qarori -> push matnlari (sof mantiq, DB'siz).
// Ota-ona: vasiylik tasdiqlansa — maktab va farzand ismi bilan (u endi vasiy); rad etilsa — ismsiz, neytral
// (rad etilgan ota-ona o'quvchi haqida hech narsa bilmasligi kerak). Bola: HAR DOIM neytral sarlavha, maktab
// nomisiz (bolalar e'lon push'i bilan bir xil qoida — lock-screen'da maktab ma'lumoti ko'rinmasin).

import type { PushPayload } from '../../common/fcm/fcm.service';
import { NotifLang, tr } from '../../common/i18n/notification-i18n';

/** Push `data.type` — ikkala ilova maktab bo'limini yangilab ochadi. */
export const SCHOOL_LINK_PUSH_TYPE = 'SCHOOL_LINK';

/** Bolaga yetadigan qaror natijasi. */
export type ChildLinkEvent = 'CONFIRMED' | 'REJECTED' | 'CORRECTION_KEPT' | 'UNLINKED';

export type LinkNotice =
  | { to: 'PARENT'; userId: string; event: 'GUARDIAN_CONFIRMED'; schoolId: string; studentFirstName: string }
  | { to: 'PARENT'; userId: string; event: 'GUARDIAN_REJECTED' }
  | { to: 'CHILD'; childId: string; event: ChildLinkEvent };

type Texts = Record<NotifLang, string>;

const PARENT_CONFIRMED_TITLE: Texts = {
  uz: '{school}: ulanish tasdiqlandi',
  ru: '{school}: подключение подтверждено',
  en: '{school}: link confirmed',
};
const PARENT_CONFIRMED_BODY: Texts = {
  uz: '{student} maktab maʼlumotlari endi Parvoz ilovasida ochiq.',
  ru: 'Школьные данные ({student}) теперь доступны в приложении Parvoz.',
  en: "{student}'s school info is now open in the Parvoz app.",
};
const PARENT_REJECTED_TITLE: Texts = {
  uz: 'Maktabga ulanish',
  ru: 'Подключение к школе',
  en: 'School link',
};
const PARENT_REJECTED_BODY: Texts = {
  uz: 'Soʻrovingiz tasdiqlanmadi. Savol boʻlsa, maktabga murojaat qiling.',
  ru: 'Запрос не подтверждён. Если есть вопросы, обратитесь в школу.',
  en: 'Your request was not approved. Please contact the school if you have questions.',
};

const CHILD_BODY: Record<ChildLinkEvent, Texts> = {
  CONFIRMED: {
    uz: 'Maktab boʻliming ochildi.',
    ru: 'Раздел «Школа» открыт.',
    en: 'Your School section is open.',
  },
  REJECTED: {
    uz: 'Maktab kodi tasdiqlanmadi. Yangi kodni sinf rahbaringdan soʻra.',
    ru: 'Школьный код не подтверждён. Попроси новый код у классного руководителя.',
    en: 'Your school code was not approved. Ask your class teacher for a new code.',
  },
  CORRECTION_KEPT: {
    uz: 'Maktab maʼlumoting tekshirildi va qayta ochildi.',
    ru: 'Школьные данные проверены и снова открыты.',
    en: 'Your school info was checked and is open again.',
  },
  UNLINKED: {
    uz: 'Maktab bilan bogʻlanish uzildi. Kerak boʻlsa, yangi kod kirit.',
    ru: 'Связь со школой отключена. Если нужно, введи новый код.',
    en: 'Your school link was removed. Enter a new code if needed.',
  },
};

const fill = (text: string, params: Record<string, string>) =>
  text.replace(/\{(\w+)\}/g, (match, key: string) => params[key] ?? match);

export function parentLinkPush(
  lang: NotifLang,
  notice: Extract<LinkNotice, { to: 'PARENT' }>,
  school: string,
): PushPayload {
  const data = { type: SCHOOL_LINK_PUSH_TYPE, event: notice.event };
  if (notice.event === 'GUARDIAN_REJECTED') {
    return { title: PARENT_REJECTED_TITLE[lang], body: PARENT_REJECTED_BODY[lang], data };
  }
  const params = { school: school || 'Parvoz', student: notice.studentFirstName };
  return { title: fill(PARENT_CONFIRMED_TITLE[lang], params), body: fill(PARENT_CONFIRMED_BODY[lang], params), data };
}

export function childLinkPush(lang: NotifLang, event: ChildLinkEvent): PushPayload {
  return {
    title: tr(lang, 'push.neutralTitle'),
    body: CHILD_BODY[event][lang],
    data: { type: SCHOOL_LINK_PUSH_TYPE, event },
  };
}
