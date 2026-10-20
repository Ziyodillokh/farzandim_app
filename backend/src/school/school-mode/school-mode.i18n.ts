// School Mode push matnlari (ota-onaga) — qabul qiluvchi tilida.

import { NotifLang } from '../../common/i18n/notification-i18n';

type Text = { title: string; body: string };

const TEXTS: Record<'permission' | 'link', Record<NotifLang, Text>> = {
  /** Bola ilovasi ulangan, lekin cheklov ruxsati o'chiq. */
  permission: {
    uz: {
      title: 'Maktab: telefon tartibi',
      body: '{school} dars vaqtidagi telefon tartibi ishlashi uchun {name} telefonida Parvoz ruxsatini yoqishingizni so\'raydi.',
    },
    ru: {
      title: 'Школа: режим телефона',
      body: '{school} просит включить разрешение Parvoz на телефоне ({name}), чтобы режим на уроках работал.',
    },
    en: {
      title: 'School: phone mode',
      body: '{school} asks you to turn on the Parvoz permission on {name}\'s phone so the lesson-time mode works.',
    },
  },
  /** Bola telefoni hali Parvoz bola ilovasiga ulanmagan. */
  link: {
    uz: {
      title: 'Maktab: Parvoz bola ilovasi',
      body: '{school} {name} telefonini Parvoz bola ilovasiga ulashingizni so\'raydi — dars vaqtidagi tartib shunda ishlaydi.',
    },
    ru: {
      title: 'Школа: детское приложение Parvoz',
      body: '{school} просит подключить телефон ({name}) к детскому приложению Parvoz — тогда режим на уроках заработает.',
    },
    en: {
      title: 'School: Parvoz child app',
      body: '{school} asks you to connect {name}\'s phone to the Parvoz child app so the lesson-time mode can work.',
    },
  },
};

export function remindText(kind: 'permission' | 'link', lang: NotifLang, vars: { school: string; name: string }): Text {
  const t = TEXTS[kind][lang];
  const fill = (s: string) => s.replace('{school}', vars.school).replace('{name}', vars.name);
  return { title: t.title, body: fill(t.body) };
}
