import type {
  AgeGroup,
  CareQuestion,
  CareRequest,
  CareResponse,
  CareSurvey,
  CareTopic,
  SchoolClass,
  Student,
} from '@/data/contracts';
import { Random, unitHash } from '@/lib/rng';
import { addDays, weekStart } from '../calendar';
import { FIXED_STAFF } from './people';

export function ageGroupOf(grade: number): AgeGroup {
  return grade <= 4 ? 'G1_4' : grade <= 8 ? 'G5_8' : 'G9_11';
}

const ALL: AgeGroup[] = ['G1_4', 'G5_8', 'G9_11'];
const OLDER: AgeGroup[] = ['G5_8', 'G9_11'];

/** Savollar banki — bolalar psixologlari bilan kelishilgan namunaviy savollar (demo). */
export function buildQuestions(): CareQuestion[] {
  const q = (id: string, topic: CareTopic, ageGroups: AgeGroup[], uz: string, ru: string, reverse = false): CareQuestion => ({
    id,
    topic,
    ageGroups,
    text: { uz, ru },
    reverse,
    active: true,
  });
  return [
    q('q-1', 'WELLBEING', ALL, 'Bu hafta maktabda o\'zingni qanchalik xotirjam his qilding?', 'Насколько спокойно ты чувствовал(а) себя в школе на этой неделе?'),
    q('q-2', 'WELLBEING', ALL, 'Maktabga kelishni qanchalik xohlading?', 'Насколько тебе хотелось приходить в школу?'),
    q('q-3', 'LEARNING', ALL, 'Darslar senga qanchalik tushunarli bo\'ldi?', 'Насколько понятными были уроки?'),
    q('q-4', 'SUPPORT', ALL, 'Darsni tushunmaganingda yordam so\'ray olasanmi?', 'Можешь ли ты попросить помощи, если не понял(а) урок?'),
    q('q-5', 'PEERS', ALL, 'Sinfdoshlaring bilan munosabating qanday?', 'Как складываются отношения с одноклассниками?'),
    q('q-6', 'PEERS', OLDER, 'Maktabda seni ranjitgan yoki masxara qilgan holatlar bo\'ldimi?', 'Были ли случаи, когда тебя обижали или высмеивали в школе?', true),
    q('q-7', 'SAFETY', OLDER, 'Biror kishi seni istamagan ishingni qilishga majburladimi?', 'Кто-то заставлял тебя делать то, чего ты не хотел(а)?', true),
    q('q-8', 'SAFETY', ALL, 'Maktabda o\'zingni xavfsiz his qilasanmi?', 'Чувствуешь ли ты себя в безопасности в школе?'),
    q('q-9', 'SUPPORT', ALL, 'Qiynalganingda gaplasha oladigan ishonchli katta inson bormi?', 'Есть ли взрослый, с которым ты можешь поговорить, когда трудно?'),
    q('q-10', 'LEARNING', OLDER, 'Uy vazifalari hajmi senga qanchalik mos?', 'Насколько тебе подходит объём домашних заданий?'),
    q('q-11', 'WELLBEING', OLDER, 'Bu hafta yetarlicha uxladingmi?', 'Высыпался(ась) ли ты на этой неделе?'),
    q('q-12', 'PEERS', ['G1_4'], 'Tanaffusda birga o\'ynaydigan do\'sting bormi?', 'Есть ли у тебя друг, с которым ты играешь на перемене?'),
    q('q-13', 'FEEDBACK', OLDER, 'Maktabdagi o\'zgarishlar sen uchun qanchalik foydali bo\'ldi?', 'Насколько полезными для тебя были изменения в школе?'),
    q('q-14', 'SAFETY', ['G9_11'], 'Internetda senga yoqmagan yozishmalar bo\'ldimi?', 'Были ли в интернете неприятные для тебя переписки?', true),
    q('q-15', 'LEARNING', ['G1_4'], 'Darsda o\'qituvchi seni maqtadimi?', 'Хвалил(а) ли тебя учитель на уроке?'),
  ];
}

/** Sinf bo'yicha "fon" darajasi — ba'zi sinflarda tengdoshlar munosabati pastroq (demo insight). */
function classBias(classId: string, topic: CareTopic): number {
  const special: Record<string, Partial<Record<CareTopic, number>>> = {
    'cls-8b': { PEERS: -0.9, SAFETY: -0.5 },
    'cls-6a': { LEARNING: -0.6 },
    'cls-10b': { WELLBEING: -0.7 },
  };
  return (special[classId]?.[topic] ?? 0) + (unitHash(classId, topic) - 0.5) * 0.4;
}

/**
 * Bitta o'quvchining javoblari (seed va jonli simulyatsiya uchun yagona model):
 * sinf "foni" + shovqin, 1..5 oralig'ida; teskari savollar aylantirib yoziladi.
 * `noise` — [0,1) manba (seed'da ketma-ket RNG, simulyatsiyada (so'rovnoma, o'quvchi) xeshi).
 */
export function generateAnswers(
  questions: readonly CareQuestion[],
  cls: Pick<SchoolClass, 'id' | 'grade'>,
  noise: () => number,
): Record<string, number> {
  const group = ageGroupOf(cls.grade);
  const answers: Record<string, number> = {};
  for (const question of questions) {
    if (!question.ageGroups.includes(group)) continue;
    const base = 3.9 + classBias(cls.id, question.topic) + (noise() - 0.5) * 1.6;
    const score = Math.min(5, Math.max(1, Math.round(base)));
    answers[question.id] = question.reverse ? 6 - score : score;
  }
  return answers;
}

export function buildSurveys(baseIso: string, classes: SchoolClass[], students: Student[], questions: CareQuestion[], seed: number) {
  const rng = new Random(seed + 17);
  const thisWeek = weekStart(baseIso);
  const surveys: CareSurvey[] = [];
  const responses: CareResponse[] = [];
  const classById = new Map(classes.map((c) => [c.id, c]));

  for (let w = 3; w >= 0; w--) {
    const start = addDays(thisWeek, -7 * w);
    const id = `srv-${start}`;
    const active = w === 0;
    const chosen = questions.filter((q) => q.active).filter((_, i) => (i + w) % 3 !== 0).slice(0, 8);
    const survey: CareSurvey = {
      id,
      title: active ? 'Haftalik so\'rovnoma — joriy hafta' : `Haftalik so'rovnoma — ${start}`,
      weekStart: start,
      ageGroups: ALL,
      questionIds: chosen.map((q) => q.id),
      status: active ? 'ACTIVE' : 'CLOSED',
      invited: students.length,
    };
    surveys.push(survey);

    const participation = active ? 0.46 : 0.72 + rng.float() * 0.12;
    for (const student of students) {
      if (!rng.bool(participation)) continue;
      const cls = classById.get(student.classId);
      if (!cls) continue;
      const answers = generateAnswers(chosen, cls, () => rng.float());
      responses.push({
        id: `rsp-${id}-${student.id}`,
        surveyId: id,
        studentId: student.id,
        classId: cls.id,
        grade: cls.grade,
        answers,
        submittedAt: `${addDays(start, rng.int(0, 4))}T${String(rng.int(15, 21)).padStart(2, '0')}:${String(rng.int(0, 59)).padStart(2, '0')}:00`,
      });
    }
  }
  return { surveys, responses };
}

export function buildCareRequests(students: Student[], baseIso: string): CareRequest[] {
  const byClass = (classId: string, i: number) => students.filter((s) => s.classId === classId)[i];
  const at = (offset: number, time: string) => `${addDays(baseIso, offset)}T${time}:00`;
  const spec: Array<[Student | undefined, Omit<CareRequest, 'id' | 'studentId' | 'classId'>]> = [
    [byClass('cls-8b', 4), { createdAt: at(0, '07:52'), topic: 'BULLYING', message: 'Tanaffuslarda bir guruh bolalar meni doim masxara qilishadi. Uyalib hech kimga aytolmadim.', urgency: 'URGENT', status: 'NEW', meetingAt: null, notes: [], protocolActivated: false }],
    [byClass('cls-10b', 7), { createdAt: at(-1, '19:20'), topic: 'EMOTIONS', message: 'Oxirgi paytlarda uxlay olmayapman, imtihonlardan juda qo\'rqaman.', urgency: 'NORMAL', status: 'NEW', meetingAt: null, notes: [], protocolActivated: false }],
    [byClass('cls-6a', 2), { createdAt: at(-1, '16:05'), topic: 'LEARNING', message: 'Matematikani umuman tushunmayapman, so\'rashga uyalaman.', urgency: 'NORMAL', status: 'IN_PROGRESS', meetingAt: null, notes: [{ at: at(0, '09:10'), byStaffId: FIXED_STAFF.psychologist, text: 'Sinf rahbari bilan qo\'shimcha mashg\'ulot imkoniyatini muhokama qilaman (ism aytilmaydi).' }], protocolActivated: false }],
    [byClass('cls-9a', 9), { createdAt: at(-2, '20:40'), topic: 'FAMILY', message: 'Uyda vaziyat og\'ir, kim bilandir gaplashgim keladi.', urgency: 'NORMAL', status: 'SCHEDULED', meetingAt: at(1, '12:30'), notes: [{ at: at(-1, '10:00'), byStaffId: FIXED_STAFF.psychologist, text: 'Suhbat ertaga katta tanaffusda, psixolog xonasida.' }], protocolActivated: false }],
    [byClass('cls-11a', 6), { createdAt: at(-3, '18:15'), topic: 'EMOTIONS', message: 'Kasb tanlashda adashib qolganman, kim bilan maslahatlashsam bo\'ladi?', urgency: 'NORMAL', status: 'RESOLVED', meetingAt: at(-1, '13:20'), notes: [{ at: at(-1, '14:00'), byStaffId: FIXED_STAFF.psychologist, text: 'Kasbga yo\'naltirish testi o\'tkazildi, tavsiyalar berildi.' }], protocolActivated: false }],
    [byClass('cls-7b', 3), { createdAt: at(-4, '17:30'), topic: 'PEERS', message: 'Yangi sinfga o\'tdim, hali do\'stlarim yo\'q.', urgency: 'NORMAL', status: 'RESOLVED', meetingAt: at(-3, '12:40'), notes: [{ at: at(-3, '13:30'), byStaffId: FIXED_STAFF.psychologist, text: 'Sinf rahbari bilan guruh topshiriqlari orqali moslashuv rejasi.' }], protocolActivated: false }],
    [byClass('cls-5b', 8), { createdAt: at(-5, '15:45'), topic: 'SAFETY', message: 'Maktabdan qaytayotganda katta bolalar pul so\'rashdi.', urgency: 'URGENT', status: 'IN_PROGRESS', meetingAt: null, notes: [{ at: at(-5, '16:10'), byStaffId: FIXED_STAFF.psychologist, text: 'Himoya protokoli ishga tushirildi: direktor va navbatchi xabardor (bolaning ismi tashqariga berilmadi).' }], protocolActivated: true }],
    [byClass('cls-8a', 1), { createdAt: at(-6, '21:10'), topic: 'OTHER', message: 'Kutubxonada ko\'proq ingliz tilidagi kitob bo\'lishini xohlardim.', urgency: 'NORMAL', status: 'RESOLVED', meetingAt: null, notes: [{ at: at(-5, '09:00'), byStaffId: FIXED_STAFF.psychologist, text: 'Taklif (anonim) ma\'muriyatga yetkazildi.' }], protocolActivated: false }],
  ];
  return spec
    .filter((entry): entry is [Student, Omit<CareRequest, 'id' | 'studentId' | 'classId'>] => Boolean(entry[0]))
    .map(([student, rest], i) => ({ id: `care-${i + 1}`, studentId: student.id, classId: student.classId, ...rest }));
}
