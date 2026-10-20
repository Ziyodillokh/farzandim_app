// Davomat push matnlari (ota-onaga) — 3 tilda. Til: `FcmService.getUserLang`.
// `{name}` — o'quvchi ismi (tarjima qilinmaydi), `{time}` — "HH:MM".

import { NotifLang } from '../../common/i18n/notification-i18n';

export type AttendancePushKey =
  | 'arrived'
  | 'late'
  | 'left'
  | 'absent'
  | 'leftEarly'
  | 'earlyExitApproved'
  | 'earlyExitRejected';

type Text = Record<NotifLang, string>;

const TEXTS: Record<AttendancePushKey, { title: Text; body: Text }> = {
  arrived: {
    title: { uz: 'Maktabga keldi', ru: 'В школе', en: 'Arrived at school' },
    body: {
      uz: '{name} maktabga {time} da keldi.',
      ru: '{name} в школе, отметка в {time}.',
      en: '{name} arrived at school at {time}.',
    },
  },
  late: {
    title: { uz: 'Kechikib keldi', ru: 'Опоздание', en: 'Late arrival' },
    body: {
      uz: '{name} maktabga {time} da kechikib keldi.',
      ru: '{name} опоздал(а), отметка в {time}.',
      en: '{name} arrived late at school at {time}.',
    },
  },
  left: {
    title: { uz: 'Maktabdan chiqdi', ru: 'Ушёл(ла) из школы', en: 'Left school' },
    body: {
      uz: '{name} maktabdan {time} da chiqdi.',
      ru: '{name} покинул(а) школу в {time}.',
      en: '{name} left school at {time}.',
    },
  },
  absent: {
    title: { uz: 'Maktabga kelmadi', ru: 'Нет в школе', en: 'Not at school' },
    body: {
      uz: '{name} bugun maktabga kelmadi.',
      ru: '{name} сегодня не отмечен(а) в школе.',
      en: '{name} has not arrived at school today.',
    },
  },
  leftEarly: {
    title: { uz: 'Erta ketdi', ru: 'Ранний уход', en: 'Left early' },
    body: {
      uz: '{name} maktabdan erta ketdi.',
      ru: '{name} покинул(а) школу раньше времени.',
      en: '{name} left school early.',
    },
  },
  earlyExitApproved: {
    title: { uz: 'Erta ketish tasdiqlandi', ru: 'Ранний уход разрешён', en: 'Early leave approved' },
    body: {
      uz: '{name} uchun erta ketish tasdiqlandi ({time}).',
      ru: '{name}: ранний уход разрешён ({time}).',
      en: 'Early leave for {name} was approved ({time}).',
    },
  },
  earlyExitRejected: {
    title: { uz: 'Erta ketish rad etildi', ru: 'Ранний уход отклонён', en: 'Early leave declined' },
    body: {
      uz: '{name} uchun erta ketish so\'rovi rad etildi.',
      ru: '{name}: запрос на ранний уход отклонён.',
      en: 'The early leave request for {name} was declined.',
    },
  },
};

function fill(template: string, params: Record<string, string>): string {
  return Object.entries(params).reduce((s, [k, v]) => s.split(`{${k}}`).join(v), template);
}

export function attendancePushText(
  lang: NotifLang,
  key: AttendancePushKey,
  params: { name: string; time: string },
): { title: string; body: string } {
  const text = TEXTS[key];
  return { title: fill(text.title[lang], params), body: fill(text.body[lang], params) };
}
