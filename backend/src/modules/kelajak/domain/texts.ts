// Kelajak ko'rsatish matnlari (uz/ru/en) — backend, admin-web, bola va
// ota-ona ilovalari uchun YAGONA manba (docs/KELAJAK-REJA.md §3 "Matnlar").
// Natijada faqat kodlar saqlanadi, matn o'qishda shu yerdan qo'shiladi.
// Siyosat: kasb bo'yicha qat'iy hukm yo'q, bolaga raqam ko'rsatilmaydi;
// taqiqlangan iboralarni texts-policy.spec.ts tekshiradi.

import type { GrowthKey, KelajakTestType, ScoredCategory } from './catalog';
import type { NextCode, SupportLevel } from './insights';
import { KELAJAK_LANGS, KelajakLang, L } from './localized';

export { RIASEC_TEXTS } from './texts-riasec';
export type { RiasecText } from './texts-riasec';

export interface TitleBody {
  title: L;
  body: L;
}

export const TEST_TEXTS: Readonly<Record<KelajakTestType, { title: L; description: L }>> = {
  daily: {
    title: { uz: 'Kunlik savollar', ru: 'Вопросы дня', en: 'Daily questions' },
    description: {
      uz: 'Har kuni bir nechta qisqa savol: o‘qish, maktab, do‘stlar va qiziqishlar haqida.',
      ru: 'Каждый день несколько коротких вопросов об учёбе, школе, друзьях и интересах.',
      en: 'A few short questions every day about learning, school, friends and interests.',
    },
  },
  career: {
    title: { uz: 'Kasbiy qiziqishlar', ru: 'Профессиональные интересы', en: 'Career interests' },
    description: {
      uz: 'Qaysi faoliyatlar senga yoqishini bilib ol — bu yo‘nalishlarni o‘rganishga yordam beradi.',
      ru: 'Узнай, какие занятия тебе нравятся, — это поможет исследовать направления.',
      en: 'Find out which activities you enjoy — it helps you explore directions.',
    },
  },
  wellbeing: {
    title: { uz: 'Kayfiyat va farovonlik', ru: 'Настроение и самочувствие', en: 'Mood and wellbeing' },
    description: {
      uz: 'O‘zingni qanday his qilayotganing va maktabda o‘zingni qanchalik xavfsiz his qilishing haqida. Ota-onang javoblaringni emas, faqat umumiy xulosani ko‘radi.',
      ru: 'О том, как ты себя чувствуешь и насколько безопасно тебе в школе. Родители видят не твои ответы, а только общий вывод.',
      en: 'About how you feel and how safe you feel at school. Your parents see only a general summary, not your answers.',
    },
  },
  learning: {
    title: { uz: 'O‘qish va maktab', ru: 'Учёба и школа', en: 'Learning and school' },
    description: {
      uz: 'Darslar, fanlar va o‘qituvchilar bilan munosabating haqida.',
      ru: 'Об уроках, предметах и отношениях с учителями.',
      en: 'About lessons, subjects and your relationship with teachers.',
    },
  },
  self: {
    title: { uz: 'Men va atrofimdagilar', ru: 'Я и окружающие', en: 'Me and others' },
    description: {
      uz: 'Do‘stlar, oila va o‘zingning xususiyatlaring haqida.',
      ru: 'О друзьях, семье и твоих личных качествах.',
      en: 'About friends, family and your personal traits.',
    },
  },
  career_lab: {
    title: { uz: 'Career Lab', ru: 'Career Lab', en: 'Career Lab' },
    description: {
      uz: 'Kasbga oid faoliyatni sinab ko‘rgach, taassurotingni baholab qo‘y.',
      ru: 'Попробовал занятие, связанное с профессией? Оцени свои впечатления.',
      en: 'Tried a career-related activity? Rate how it felt.',
    },
  },
  voice: {
    title: { uz: 'Mening fikrim', ru: 'Моё мнение', en: 'My voice' },
    description: {
      uz: 'O‘z fikringni erkin yoz. Javob berish ixtiyoriy. Bu javoblarni ota-onang ko‘rmaydi va ularni hech kim o‘qib javob qaytarmaydi — yordam kerak bo‘lsa, ishonchli kattaga ayt yoki ilovadagi SOS tugmasini bos.',
      ru: 'Напиши своё мнение свободно. Отвечать необязательно. Родители не видят эти ответы, и никто не прочитает их и не ответит — если нужна помощь, скажи взрослому, которому доверяешь, или нажми кнопку SOS в приложении.',
      en: 'Share your thoughts freely. Answering is optional. Your parents do not see these answers and no one reads or replies to them — if you need help, tell an adult you trust or press the SOS button in the app.',
    },
  },
};

export const STRENGTH_TEXTS: Readonly<Record<ScoredCategory, { title: L }>> = {
  learning: { title: { uz: 'O‘rganishga qiziqish', ru: 'Интерес к учёбе', en: 'Interest in learning' } },
  school_quality: {
    title: { uz: 'Maktabdagi ijobiy tajriba', ru: 'Позитивный опыт в школе', en: 'Positive school experience' },
  },
  teacher_relation: {
    title: {
      uz: 'O‘qituvchilar bilan yaxshi munosabat',
      ru: 'Хорошие отношения с учителями',
      en: 'Good relationship with teachers',
    },
  },
  social_self: {
    title: { uz: 'Muloqot va o‘zini anglash', ru: 'Общение и самопознание', en: 'Social skills and self-awareness' },
  },
  career_planning: {
    title: { uz: 'Kelajakni rejalashtirish', ru: 'Планирование будущего', en: 'Planning for the future' },
  },
  parent_communication: {
    title: {
      uz: 'Ota-ona bilan ochiq muloqot',
      ru: 'Открытое общение с родителями',
      en: 'Open communication with parents',
    },
  },
  personal_traits: { title: { uz: 'Shaxsiy fazilatlar', ru: 'Личные качества', en: 'Personal strengths' } },
};

export const GROWTH_TEXTS: Readonly<Record<GrowthKey, { title: L; tip: L }>> = {
  learning: {
    title: { uz: 'O‘rganish odatlari', ru: 'Учебные привычки', en: 'Learning habits' },
    tip: {
      uz: 'Har kuni ozgina vaqt qiziq mavzuni o‘rganib, tushunganlarini qisqa yozib borish foydali.',
      ru: 'Полезно каждый день немного изучать интересную тему и коротко записывать понятое.',
      en: 'A little time each day on an interesting topic, with short notes on what was understood, helps.',
    },
  },
  school_quality: {
    title: { uz: 'Maktabdagi tajriba', ru: 'Опыт в школе', en: 'School experience' },
    tip: {
      uz: 'Darslarda nima yoqishi va nima qiyinligi haqida o‘qituvchi yoki ishonchli kattalar bilan gaplashish mumkin.',
      ru: 'Можно поговорить с учителем или взрослым, которому доверяешь, о том, что на уроках нравится, а что трудно.',
      en: 'Talking with a teacher or a trusted adult about what feels good and what is hard in class can help.',
    },
  },
  teacher_relation: {
    title: { uz: 'O‘qituvchilar bilan muloqot', ru: 'Общение с учителями', en: 'Talking with teachers' },
    tip: {
      uz: 'Tushunmagan narsani o‘qituvchidan so‘rashdan tortinmaslik muloqotni osonlashtiradi.',
      ru: 'Не стесняться спрашивать учителя о непонятном — так общаться становится легче.',
      en: 'Asking the teacher about anything unclear makes communication easier.',
    },
  },
  social_self: {
    title: { uz: 'Muloqot ko‘nikmalari', ru: 'Навыки общения', en: 'Social skills' },
    tip: {
      uz: 'Kichik qadamlar yordam beradi: yangi odam bilan salomlashish yoki guruh ishida bitta fikr aytish.',
      ru: 'Помогают маленькие шаги: поздороваться с новым человеком или высказать одну мысль в группе.',
      en: 'Small steps help: greeting someone new or sharing one idea in group work.',
    },
  },
  career_planning: {
    title: { uz: 'Kelajak rejalari', ru: 'Планы на будущее', en: 'Future plans' },
    tip: {
      uz: 'Qiziq kasblar ro‘yxatini tuzib, ular haqida bittadan bilib borish mumkin.',
      ru: 'Можно составить список интересных профессий и узнавать о них по одной.',
      en: 'Make a list of interesting careers and learn about them one at a time.',
    },
  },
  parent_communication: {
    title: { uz: 'Oila bilan muloqot', ru: 'Общение в семье', en: 'Family communication' },
    tip: {
      uz: 'Kun oxirida bir necha daqiqa kun qanday o‘tgani haqida gaplashish odatini sinab ko‘rish mumkin.',
      ru: 'Можно попробовать привычку несколько минут вечером говорить о том, как прошёл день.',
      en: 'Try a habit of spending a few minutes in the evening talking about the day.',
    },
  },
  personal_traits: {
    title: { uz: 'O‘ziga ishonch', ru: 'Уверенность в себе', en: 'Self-confidence' },
    tip: {
      uz: 'Bitta kichik maqsad qo‘yib, uni bajarish o‘ziga ishonchni oshiradi.',
      ru: 'Поставить одну небольшую цель и выполнить её — это добавляет уверенности.',
      en: 'Setting one small goal and reaching it builds confidence.',
    },
  },
  // Xavfsizlik bilimi savollari (signal emas): qoidani bilmaslik — tashvish belgisi emas.
  safety_rules: {
    title: { uz: 'Xavfsizlik qoidalari', ru: 'Правила безопасности', en: 'Safety rules' },
    tip: {
      uz: 'Xavfli vaziyatda nima qilish, kimga murojaat qilish va internetda shaxsiy ma’lumotni qanday asrashni kattalar bilan birga takrorlab chiqish foydali.',
      ru: 'Полезно вместе со взрослыми повторить, что делать в опасной ситуации, к кому обращаться и как защищать личные данные в интернете.',
      en: 'It helps to go over with an adult what to do in a risky situation, whom to turn to, and how to keep personal information safe online.',
    },
  },
};

/** Bolaga: mehribon, raqamsiz; ishonchli kattalar va xavf bo'lsa SOS tugmasi. */
export const SUPPORT_CHILD_TEXTS: Readonly<Record<SupportLevel, L>> = {
  none: {
    uz: 'Javoblaring uchun rahmat! O‘zingni qanday his qilayotganing muhim. Biror narsa bezovta qilsa, ishonchli kattalar bilan gaplashish har doim mumkin.',
    ru: 'Спасибо за ответы! Важно, как ты себя чувствуешь. Если что-то беспокоит, всегда можно поговорить со взрослым, которому ты доверяешь.',
    en: 'Thanks for your answers! How you feel matters. If something bothers you, you can always talk to an adult you trust.',
  },
  watch: {
    uz: 'Ba’zan hammaga qiyin bo‘ladi — bu tabiiy. Agar biror narsa seni bezovta qilayotgan bo‘lsa, ishonchli kattalardan biri — ota-onang, o‘qituvching yoki maktab psixologi bilan gaplashib ko‘r. Xavf his qilsang, ilovadagi SOS tugmasini bos.',
    ru: 'Иногда всем бывает трудно — это нормально. Если тебя что-то беспокоит, поговори со взрослым, которому доверяешь: с родителями, учителем или школьным психологом. Если чувствуешь опасность, нажми кнопку SOS в приложении.',
    en: 'Everyone has hard times sometimes — that is okay. If something is bothering you, talk to an adult you trust: a parent, a teacher or the school psychologist. If you feel in danger, press the SOS button in the app.',
  },
  support: {
    uz: 'Seni nimadir qiynayotganga o‘xshaydi. Sen yolg‘iz emassan. Bugun ishonchli kattalardan biri — ota-onang, o‘qituvching yoki maktab psixologi bilan gaplashib ko‘r: ular yordam berishni xohlaydi. Agar o‘zingni xavf ostida his qilsang, darhol ilovadagi SOS tugmasini bos.',
    ru: 'Похоже, тебя что-то тревожит. Ты не один. Поговори сегодня со взрослым, которому доверяешь: с родителями, учителем или школьным психологом — они хотят помочь. Если чувствуешь опасность, сразу нажми кнопку SOS в приложении.',
    en: 'It looks like something is weighing on you. You are not alone. Try talking today to an adult you trust — a parent, a teacher or the school psychologist; they want to help. If you feel in danger, press the SOS button in the app right away.',
  },
};

/** Ota-onaga: xotirjam ohang, "bu tashxis emas"; `none` darajasi ota-onaga ko'rsatilmaydi. */
export const SUPPORT_PARENT_TEXTS: Readonly<Record<Exclude<SupportLevel, 'none'>, L>> = {
  watch: {
    uz: 'Farzandingiz so‘nggi javoblarida ba’zi qiyinchiliklarni belgiladi. Bu tashxis emas — e’tibor berish uchun signal, xolos. Xotirjam vaziyatda kayfiyati va kuni haqida so‘rang va tanbehsiz tinglang.',
    ru: 'В последних ответах ребёнок отметил некоторые трудности. Это не диагноз — лишь повод быть внимательнее. В спокойной обстановке спросите о настроении и прошедшем дне и выслушайте без упрёков.',
    en: 'In recent answers your child noted some difficulties. This is not a diagnosis — just a signal to pay attention. In a calm moment, ask about their mood and day, and listen without judgement.',
  },
  support: {
    uz: 'Farzandingiz so‘nggi javoblarida bir nechta qiyinchilikni belgiladi. Bu tashxis emas, lekin e’tibor va qo‘llab-quvvatlash muhim. Farzandingiz bilan xotirjam gaplashing, uni tinglang va ayblamang. Xavotir saqlansa, maktab psixologi yoki mutaxassis bilan maslahatlashing.',
    ru: 'В последних ответах ребёнок отметил несколько трудностей. Это не диагноз, но важны внимание и поддержка. Спокойно поговорите с ребёнком, выслушайте его и не обвиняйте. Если беспокойство сохраняется, обратитесь к школьному психологу или специалисту.',
    en: 'In recent answers your child noted several difficulties. This is not a diagnosis, but attention and support matter. Talk calmly with your child, listen and avoid blame. If concerns persist, consult the school psychologist or a specialist.',
  },
};

export type NextTextKey = 'career' | 'wellbeing' | 'career_lab_try' | 'career_lab_deepen' | 'come_back';

/** Keyingi tavsiya matnlari; `{activity}` — Career Lab faoliyati nomi. */
export const NEXT_TEXTS: Readonly<Record<NextTextKey, TitleBody>> = {
  career: {
    title: { uz: 'Kasbiy qiziqishlar testi', ru: 'Тест профессиональных интересов', en: 'Career interests test' },
    body: {
      uz: 'Qiziqishlar profilini to‘ldirish uchun “Kasbiy qiziqishlar” testini yechish tavsiya etiladi.',
      ru: 'Чтобы дополнить профиль интересов, рекомендуем пройти тест «Профессиональные интересы».',
      en: 'Take the “Career interests” test to complete the interests profile.',
    },
  },
  wellbeing: {
    title: { uz: 'Kayfiyat tekshiruvi', ru: 'Проверка настроения', en: 'Mood check-in' },
    body: {
      uz: 'Bir necha qisqa savol — kayfiyat va o‘zini qanday his qilish haqida.',
      ru: 'Несколько коротких вопросов о настроении и самочувствии.',
      en: 'A few short questions about mood and how things are going.',
    },
  },
  career_lab_try: {
    title: { uz: 'Yangi faoliyatni sinab ko‘rish', ru: 'Попробовать новое занятие', en: 'Try a new activity' },
    body: {
      uz: 'Qiziqishlarga mos faoliyat: {activity}. Sinab ko‘rgach, taassurotni Career Lab’da baholash mumkin.',
      ru: 'Занятие по интересам: {activity}. После пробы впечатления можно оценить в Career Lab.',
      en: 'An activity that matches the interests: {activity}. After trying it, rate the experience in Career Lab.',
    },
  },
  career_lab_deepen: {
    title: { uz: 'Yoqqan faoliyatni davom ettirish', ru: 'Продолжить понравившееся занятие', en: 'Go deeper' },
    body: {
      uz: '“{activity}” yoqdi — shu yo‘nalishda biroz murakkabroq vazifani sinab ko‘rish mumkin.',
      ru: '«{activity}» понравилось — можно попробовать задание посложнее в этом направлении.',
      en: '“{activity}” was enjoyable — try a slightly harder task in the same direction.',
    },
  },
  come_back: {
    title: { uz: 'Ertaga yana', ru: 'До завтра', en: 'See you tomorrow' },
    body: {
      uz: 'Har kuni bir nechta savol — profil asta-sekin to‘liqroq bo‘ladi.',
      ru: 'Несколько вопросов каждый день — и профиль постепенно станет полнее.',
      en: 'A few questions a day make the profile more complete over time.',
    },
  },
};

export const DISCLAIMERS: Readonly<{ child: L; parent: L }> = {
  child: {
    uz: 'Bu natijalar — yo‘nalish tanlashga yordam beruvchi tavsiya, qat’iy hukm emas. Qiziqishlar vaqt bilan o‘zgaradi, turli faoliyatlarni sinab ko‘rish foydali.',
    ru: 'Эти результаты — подсказка для выбора направления, а не окончательный вывод. Интересы меняются со временем, полезно пробовать разное.',
    en: 'These results are a hint for exploring directions, not a final verdict. Interests change over time, so trying different things helps.',
  },
  parent: {
    uz: 'Natijalar bolaning o‘z javoblariga asoslangan va yo‘nalish uchun tavsiya, qat’iy kasb hukmi emas. Farovonlik savollari tashxis vositasi emas. Savollar ekspert ko‘rigi va pilot sinovdan o‘tmoqda.',
    ru: 'Результаты основаны на ответах ребёнка и служат ориентиром, а не окончательным выбором профессии. Вопросы о самочувствии не являются инструментом диагностики. Вопросы проходят экспертную проверку и пилотное тестирование.',
    en: 'Results are based on the child’s own answers and offer guidance for exploring directions, not a final career verdict. Wellbeing questions are not a diagnostic tool. The questions are undergoing expert review and pilot testing.',
  },
};

/** `{nom}` o'rinlarini to'ldirish (til yo'q bo'lsa `uz`). */
export function fillL(text: L, vars: Readonly<Record<string, L>>): L {
  const fill = (lang: KelajakLang, value: string) =>
    value.replace(/\{(\w+)\}/g, (match, key: string) =>
      Object.prototype.hasOwnProperty.call(vars, key) ? (vars[key][lang] ?? vars[key].uz) : match,
    );
  return Object.fromEntries(
    KELAJAK_LANGS.flatMap((lang) => {
      const value = text[lang];
      return value === undefined ? [] : [[lang, fill(lang, value)]];
    }),
  ) as L;
}

export function nextTextKey(code: NextCode): NextTextKey {
  if (code.kind === 'career_lab') return code.mode === 'deepen' ? 'career_lab_deepen' : 'career_lab_try';
  if (code.kind === 'take_test' && code.testType === 'wellbeing') return 'wellbeing';
  if (code.kind === 'take_test') return 'career';
  return 'come_back';
}

/** Tavsiya matni; Career Lab uchun faoliyat nomi qo'yiladi. */
export function nextText(code: NextCode, activity: L | null): TitleBody {
  const text = NEXT_TEXTS[nextTextKey(code)];
  const vars = { activity: activity ?? { uz: '—' } };
  return { title: fillL(text.title, vars), body: fillL(text.body, vars) };
}
