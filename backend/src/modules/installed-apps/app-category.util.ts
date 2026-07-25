// ─────────────────────────────────────────────────────────────────────
// app-category.util — paket nomidan ilova kategoriyasini aniqlash (#14)
// ─────────────────────────────────────────────────────────────────────
//
// Kategoriyalar: SOCIAL (ijtimoiy tarmoq), GAME (o'yin), VIDEO (video/striming),
// EDU (ta'lim), OTHER (boshqa). Mashhur paketlar uchun aniq jadval + paket
// nomidagi kalit so'zlar bo'yicha evristik. Aniqlanmasa OTHER.
//
// Bola qurilmasi kelajakda ApplicationInfo.category yuborsa, uni ustun qo'yish
// mumkin — hozircha bu klassifikator yetarli (O'zbekistonda keng tarqalgan
// ijtimoiy/video/o'yin ilovalarini qamrab oladi).

export type AppCategory = 'SOCIAL' | 'GAME' | 'VIDEO' | 'EDU' | 'OTHER';

export const APP_CATEGORIES: AppCategory[] = [
  'SOCIAL',
  'GAME',
  'VIDEO',
  'EDU',
  'OTHER',
];

/** Mashhur paketlar — aniq kategoriya. */
const EXACT: Record<string, AppCategory> = {
  // SOCIAL
  'com.instagram.android': 'SOCIAL',
  'com.facebook.katana': 'SOCIAL',
  'com.facebook.orca': 'SOCIAL',
  'com.facebook.lite': 'SOCIAL',
  'com.whatsapp': 'SOCIAL',
  'com.whatsapp.w4b': 'SOCIAL',
  'org.telegram.messenger': 'SOCIAL',
  'org.telegram.messenger.web': 'SOCIAL',
  'org.telegram.plus': 'SOCIAL', // Plus Messenger (Telegram forki — UZ'da mashhur)
  'org.thunderdog.challegram': 'SOCIAL', // Telegram X
  'com.snapchat.android': 'SOCIAL',
  'com.twitter.android': 'SOCIAL',
  'com.vkontakte.android': 'SOCIAL',
  'ru.ok.android': 'SOCIAL',
  'com.linkedin.android': 'SOCIAL',
  'com.pinterest': 'SOCIAL',
  'com.discord': 'SOCIAL',
  'com.imo.android.imoim': 'SOCIAL',
  'com.viber.voip': 'SOCIAL',
  'jp.naver.line.android': 'SOCIAL',
  'com.zing.zalo': 'SOCIAL',
  'com.skype.raider': 'SOCIAL',
  // VIDEO / striming (TikTok ham — qisqa video striming)
  'com.google.android.youtube': 'VIDEO',
  'com.google.android.apps.youtube.kids': 'VIDEO',
  'com.zhiliaoapp.musically': 'VIDEO',
  'com.ss.android.ugc.trill': 'VIDEO',
  'com.netflix.mediaclient': 'VIDEO',
  'com.amazon.avod.thirdpartyclient': 'VIDEO',
  'tv.twitch.android.app': 'VIDEO',
  'com.google.android.videos': 'VIDEO',
  'com.uztelecom.megogo': 'VIDEO',
  // GAME
  'com.mojang.minecraftpe': 'GAME',
  'com.roblox.client': 'GAME',
  'com.dts.freefireth': 'GAME',
  'com.dts.freefiremax': 'GAME',
  'com.activision.callofduty.shooter': 'GAME',
  'com.tencent.ig': 'GAME',
  'com.pubg.imobile': 'GAME',
  'com.supercell.clashofclans': 'GAME',
  'com.supercell.clashroyale': 'GAME',
  'com.supercell.brawlstars': 'GAME',
  'com.king.candycrushsaga': 'GAME',
  'com.miHoYo.GenshinImpact': 'GAME',
  'com.innersloth.spacemafia': 'GAME',
  'com.ea.gp.fifamobile': 'GAME',
  // EDU
  'com.duolingo': 'EDU',
  'org.khanacademy.android': 'EDU',
  'com.google.android.apps.classroom': 'EDU',
  'com.quizlet.quizletandroid': 'EDU',
  'com.photomath': 'EDU',
  'com.microblink.photomath': 'EDU',
  'com.brainly': 'EDU',
  'co.brainly': 'EDU',
};

/** Paket nomidagi kalit so'z bo'yicha evristik (EXACT topilmasa). */
const KEYWORDS: { needle: string; category: AppCategory }[] = [
  { needle: 'game', category: 'GAME' },
  { needle: 'games', category: 'GAME' },
  { needle: 'playrix', category: 'GAME' },
  { needle: 'gameloft', category: 'GAME' },
  { needle: 'supercell', category: 'GAME' },
  { needle: 'miniclip', category: 'GAME' },
  { needle: 'telegram', category: 'SOCIAL' }, // barcha Telegram forklari (Plus...)
  { needle: 'messenger', category: 'SOCIAL' },
  { needle: 'social', category: 'SOCIAL' },
  { needle: 'chat', category: 'SOCIAL' },
  { needle: 'video', category: 'VIDEO' },
  { needle: 'player', category: 'VIDEO' },
  { needle: 'tv', category: 'VIDEO' },
  { needle: 'edu', category: 'EDU' },
  { needle: 'learn', category: 'EDU' },
  { needle: 'school', category: 'EDU' },
  { needle: 'maktab', category: 'EDU' },
];

/** Paket nomidan kategoriya. Hech narsa mos kelmasa OTHER. */
export function classifyPackage(packageName: string): AppCategory {
  const pkg = packageName.toLowerCase();
  const exact = EXACT[packageName];
  if (exact) return exact;
  for (const { needle, category } of KEYWORDS) {
    if (pkg.includes(needle)) return category;
  }
  return 'OTHER';
}

/** UI uchun o'zbekcha kategoriya nomi. */
export function categoryLabel(category: string): string {
  switch (category) {
    case 'SOCIAL':
      return 'Ijtimoiy tarmoqlar';
    case 'GAME':
      return "O'yinlar";
    case 'VIDEO':
      return 'Video';
    case 'EDU':
      return "Ta'lim";
    default:
      return 'Boshqa';
  }
}
