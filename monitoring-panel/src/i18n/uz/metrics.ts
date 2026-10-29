/** Ko'rsatkichlar: qisqa nom, to'liq nom va ta'rif (metodologiya ham shundan foydalanadi). */
export const metrics = {
  coverage: {
    label: 'Qamrov',
    title: 'Monitoring qamrovi',
    description: 'Parvoz\'ga ulangan o\'quvchilarning rasmiy o\'quvchilar soniga nisbati.',
  },
  active: {
    label: 'Faollik',
    title: 'Faol o\'quvchilar (30 kun)',
    description: 'Oxirgi 30 kunda kamida bitta test yoki topshiriq bajargan o\'quvchilar ulushi.',
  },
  parents: {
    label: 'Ota-onalar',
    title: 'Ota-onasi ulangan o\'quvchilar',
    description: 'Kamida bitta ota-onasi Parvoz Parents ilovasiga ulangan o\'quvchilar ulushi.',
  },
  mastery: {
    label: 'O\'zlashtirish',
    title: 'O\'rtacha o\'zlashtirish',
    description: 'Kundalik testlarda to\'g\'ri javoblar ulushi (Σ to\'g\'ri / Σ savol), fanlar bo\'yicha.',
  },
  success: {
    label: 'Muvaffaqiyat',
    title: 'Muvaffaqiyatli testlar',
    description: '80% va undan yuqori natija bilan yakunlangan testlar ulushi.',
  },
  tests: {
    label: 'Testlar',
    title: 'Haftalik testlar',
    description: 'Bir faol o\'quvchiga haftasiga yechilgan testlar soni.',
  },
  iqParticipation: {
    label: 'IQ qamrovi',
    title: 'Parvoz IQ qamrovi',
    description: '9 yoshdan katta o\'quvchilar orasida Parvoz IQ testini yakunlaganlar ulushi.',
  },
  iqMean: {
    label: 'IQ (o\'rtacha)',
    title: 'O\'rtacha standart ball',
    description: 'Yosh normasi bo\'yicha standart ball (100 ± 15) o\'rtachasi. Skrining, tashxis emas.',
  },
  iqHigh: {
    label: 'Yuqori daraja',
    title: 'O\'rtachadan yuqori va undan baland',
    description: 'Standart ball 110 va undan yuqori bo\'lgan bolalar ulushi.',
  },
  iqGrowthZone: {
    label: 'Rivojlanish zonasi',
    title: 'Rivojlanish zonasi',
    description: 'Standart ball 80 dan past — qo\'shimcha rivojlantiruvchi mashg\'ulot tavsiya etiladigan bolalar ulushi.',
  },
  careerReadiness: {
    label: 'Kasbga tayyorgarlik',
    title: 'Kasbga tayyorgarlik indeksi',
    description: 'Parvoz Kelajak: kasbni rejalashtirish bo\'yicha o\'z-o\'zini baholash (0–100), 7-sinfdan.',
  },
  wellbeing: {
    label: 'Farovonlik',
    title: 'Farovonlik indeksi',
    description: '"Bola ovozi" so\'rovnomasi: o\'zini his qilish mavzusi bali (0–100, yuqori — yaxshi).',
  },
  bullying: {
    label: 'Bulling signali',
    title: 'Bulling signali',
    description: 'Masxara, tazyiq yoki internetdagi yoqimsiz yozishmalar haqidagi savollarga "ko\'pincha" yoki "ha" deb javob berganlar ulushi.',
  },
  support: {
    label: 'Qo\'llab-quvvatlash',
    title: 'Qo\'llab-quvvatlash signali',
    description: 'Parvoz Kelajak farovonlik savollarida ikki va undan ortiq xavotirli javob bergan bolalar ulushi.',
  },
  anxiety: {
    label: 'Xavotir',
    title: 'Xavotir skriningi',
    description: 'Hissiy holat skriningida "kuzatib borish" yoki "psixolog suhbati" darajasidagi bolalar ulushi.',
  },
  sleep: {
    label: 'Uyqu yetishmasligi',
    title: 'Yetarli uxlamaganlar',
    description: 'Haftalik so\'rovnomada yetarlicha uxlamaganini aytgan bolalar ulushi.',
  },
  careRequests: {
    label: 'Murojaatlar',
    title: 'Psixologga murojaatlar',
    description: 'Oyiga 1000 o\'quvchiga to\'g\'ri keladigan "Bola ovozi" murojaatlari. Ko\'p murojaat ko\'pincha ishonch yuqoriligini bildiradi.',
  },
  safetyGap: {
    label: 'Xavfsizlik bilimi',
    title: 'Xavfsizlik qoidalari bo\'yicha bo\'shliq',
    description: 'Parvoz Kelajak: xavfsizlik bilimlari savollarida o\'sish zonasida bo\'lgan bolalar ulushi.',
  },
  schoolQuality: {
    label: 'Maktab sifati',
    title: 'Maktab sifati (bolalar fikri)',
    description: 'Bolalarning maktab va darslar sifatiga bergan bahosi (0–100).',
  },
  teacherRelation: {
    label: 'O\'qituvchi bilan munosabat',
    title: 'O\'qituvchi bilan munosabat',
    description: 'Bolalarning o\'qituvchilar bilan munosabatga bahosi (0–100).',
  },
  attendance: {
    label: 'Davomat',
    title: 'Davomat darajasi',
    description: '(Keldi + kechikdi + erta ketdi) / belgilangan o\'quvchi-kunlar.',
  },
  late: {
    label: 'Kechikish',
    title: 'Kechikish',
    description: 'Smena boshlanishidan keyin kelganlar ulushi.',
  },
  chronic: {
    label: 'Surunkali kelmaslik',
    title: 'Surunkali kelmaslik',
    description: 'O\'quv kunlarining 10% va undan ko\'pida kelmagan o\'quvchilar ulushi.',
  },
  screenTime: {
    label: 'Ekran vaqti',
    title: 'O\'rtacha kunlik ekran vaqti',
    description: 'Ota-ona ulagan qurilmalarda kunlik o\'rtacha foydalanish (daqiqa).',
  },
  night: {
    label: 'Tungi foydalanish',
    title: 'Tungi foydalanish',
    description: 'Ekran vaqtining 22:00–06:00 oralig\'iga to\'g\'ri keladigan ulushi.',
  },
  schoolMode: {
    label: 'Dars rejimi',
    title: 'Dars rejimiga rioya',
    description: 'Dars soatlarida telefon chalg\'ituvchi ilovalardan qulflangan vaqt ulushi.',
  },
  steps: {
    label: 'Qadamlar',
    title: 'Kunlik qadamlar',
    description: 'Ota-ona ulagan qurilmalarda kunlik qadamlar medianasi.',
  },
};
