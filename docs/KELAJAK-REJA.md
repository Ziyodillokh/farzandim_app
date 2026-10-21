# Parvoz Kelajak — savollar banki integratsiyasi (reja va API kontrakti)

Manba: `backend/prisma/data/kelajak/parvoz_question_bank_278.json` (foydalanuvchi bergan fayl, baytma-bayt nusxa,
sha256 `1359fc1d2c4400716467742d795b54e5586d78dee51dec78ec2a4afae27d06e1`). JSON **o'zgartirilmaydi**.

Bu hujjat backend, admin-web, bola ilovasi (`farzandim_child`) va ota-ona ilovasi (`Farzandim`) uchun YAGONA kontrakt.

## 0. Nega yangi model

| Mavjud tizim | Nega yetarli emas |
|---|---|
| `LearningQuestion` / `LearningAttempt` (Growth kunlik fan testlari) | Bitta to'g'ri javob (`answerIndex`), `subject` enum, sinf (1–11), DON / aniqlik statistikasi, maktab Growth kataklari. O'z-o'zini baholash savolida to'g'ri javob yo'q, yosh guruhi, shkala, kategoriya, o'lcham (RIASEC) bor. Aralashtirilsa fan statistikasi va maktab hisobotlari buziladi. |
| `SchoolPsychTest`, `SchoolCare*` | `schoolId` majburiy (maktab tenanti). Kelajak — maktabga bog'lanmagan har bir Growth bolasi uchun. |

Shuning uchun 3 ta yangi jadval, lekin mavjud naqshlar qayta ishlatiladi:
- import — `learning` bankidagi kabi generatsiya qilingan ma'lumot migratsiyasi, `externalId` bo'yicha `ON CONFLICT DO NOTHING`;
- urinish naqshi — Toshkent kuni, bola bo'yicha advisory lock, idempotent yakunlash, `ABANDONED`;
- auth guard'lar va admin ruxsati — mavjud `manage_learning`;
- matn shifrlash — `SchoolCryptoService` (`SCHOOL_DATA_KEY`, AES-256-GCM);
- yosh — `Child.birthDate` / `Child.age`.

## 1. JSON tekshiruvi (natija)

- **Struktura:**
  - JSON valid, 278 savol, `total_questions` mos.
  - ID'lar unikal va ketma-ket (`PARVOZ-Q001…Q278`); matn dublikati yo'q.
  - 12 kategoriya; nom va sonlar `categories` va `statistics` bilan mos.
  - Yosh: 7-9 → 70, 10-12 → 68, 13-15 → 69, 16-18 → 71.
  - Har savolda `question_text` va `source_*` bor.
  - Variantlar `answer_scales` bilan aynan bir xil; `scoring` bor (`text`dan boshqa hammasida).
  - Bu tekshiruvlar avtomatik: `parseKelajakBank` yaxlitlik ogohlantirishlari (`bank-integrity.ts`: variantlar ↔ `answer_scales`, kategoriya nomi/soni ↔ `categories`/`statistics`, yosh sonlari, scoring, ID ketma-ketligi) import hisobotiga chiqadi, migratsiya generatori esa ogohlantirishda to'xtaydi; `bank.spec.ts` faylning sha256'ini tekshiradi.
- **Mazmuniy muammolar** (`prisma/data/kelajak/review-overrides.json`da qayd etilgan; JSON tegilmaydi):
  - 8 savol bazaga **nofaol** (`active=false`, sababi `review_note`da) yoziladi. Admin matnni tuzatib, faollashtiradi.

    | ID | Muammo | Tavsiya etilgan tuzatish |
    |---|---|---|
    | Q061 | "Qaysi fan…?" + to'g'ri/to'g'ri emas shkalasi | "Biror fan yoki mashg'ulotda vaqt tez o'tib ketgandek bo'ladimi?" yoki `answer_type: text` |
    | Q067 | "Qaysi fanlarda…?" | "Ba'zi fanlarda topshiriqlarni bajarish senga osonroqmi?" yoki `text` |
    | Q072 | "Qaysi fanlarda…?" | "Ba'zi fanlarda ko'proq mashq qilishni xohlaysanmi?" yoki `text` |
    | Q073 | "Qaysi fanlar…?" | "Ba'zi fanlar kelajakdagi qiziqishlaring bilan bog'liq deb o'ylaysanmi?" yoki `text` |
    | Q090 | "…eng yoqimli qismi qaysi?" | `answer_type: text` |
    | Q213 | "Qaysi ishlarni…?" | `answer_type: text` |
    | Q214 | "…kim yordam berishi mumkin?" | `answer_type: text` |
    | Q212 | "Rejangni o'zgartirdimi?" + yoqdi/yoqmadi | `yes_no` shkalasi |

  - 3 savol faol, lekin `review_note` bilan belgilangan (ifoda yoki shkala to'liq mos emas): Q050, Q210, Q211.
- **Qutblilik:** JSON'da yo'q. Ijobiy savolda yuqori ball — yaxshi holat; teskari savolda yuqori ball — tashvish. 7 ta teskari savol: Q156, Q157, Q160, Q162, Q164, Q165, Q167 (charchoq, xavotir, bosim, yolg'izlanish, uyqu). Ular `reverse=true` bilan yoziladi; qolgan barcha savollar ijobiy.
- **Signal turi** (`scoring.signal`, `review-overrides.json` → `knowledge`): safety savollarining ko'pi bolaning holatini emas, qoidani bilishini so'raydi ("...ni bilasanmi?"). 17 ta shunday savol — Q131–Q133, Q136–Q138, Q140–Q150 — `signal: "knowledge"` bilan yoziladi: ular qo'llab-quvvatlash signaliga kirmaydi (aks holda xavfsizlik qoidasini bilmagan 7 yoshli bola ota-onaga "bullying/psixolog" signali bilan ko'rinardi), past bo'lsa faqat "Xavfsizlik qoidalari" maslahati beriladi (§3). Qolgan wellbeing/safety savollari (holat, xavfsizlik hissi, yordamga yetishish) — `distress` (standart, teg yozilmaydi).
- **Career Lab RIASEC kodi** (`scoring.riasec`, `review-overrides.json` → `careerLab`): 15 faoliyatga kod beriladi (masalan, Q194 → R); umumiy refleksiya savollari (Q193, Q208, Q210–Q212) kodsiz. Kod ma'lumotda — admin qo'shgan faoliyatga ham paneldan beriladi.
- **RIASEC muvozanati:** bir yosh guruhida o'lchamga 2 yoki 3 savol to'g'ri keladi. Shuning uchun o'lcham bali **o'rtacha** bilan hisoblanadi (`dimension_sum` emas, normallashtirilgan o'rtacha).
- **Til:** savollar faqat o'zbekcha. `text`, `options[].label` `{uz, ru?, en?}` shaklida saqlanadi; ilova `ru`/`en` bo'lmasa `uz`ni ko'rsatadi.

## 2. Ma'lumotlar modeli (Prisma, faqat qo'shuvchi migratsiyalar)

```prisma
enum KelajakSessionStatus {
  STARTED       // yaratildi, hali javob yo'q
  IN_PROGRESS   // kamida bitta javob
  COMPLETED
  ABANDONED     // o'tgan kunda yakunlanmay qolgan
}

model KelajakQuestion {
  id            String   @id @default(uuid())
  externalId    String   @unique @map("external_id")      // "PARVOZ-Q001"
  category      String                                     // career_interest, learning, ...
  ageGroup      String   @map("age_group")                 // "7-9" | "10-12" | "13-15" | "16-18"
  text          Json                                       // {uz, ru?, en?}
  answerType    String   @map("answer_type")               // interest_4 | likert_5 | career_lab_5 | text | frequency_5 | yes_no | support_4
  options       Json                                       // [{value: 1, label: {uz, ru?, en?}}], text uchun []
  scoring       Json?                                      // JSON'dagi scoring obyekti, text uchun null
  reverse       Boolean  @default(false)                   // yuqori qiymat = tashvish
  required      Boolean  @default(true)
  followUp      String?  @map("follow_up")
  notes         String?
  reviewNote    String?  @map("review_note")
  sourceType    String   @map("source_type")
  sourceName    String   @map("source_name")
  sourceVersion String   @map("source_version")
  active        Boolean  @default(true)
  createdBy     String?  @map("created_by")
  createdAt     DateTime @default(now()) @map("created_at")
  updatedAt     DateTime @updatedAt @map("updated_at")
  answers KelajakAnswer[]
  @@index([ageGroup, active, category])
  @@map("kelajak_questions")
}

model KelajakSession {
  id          String               @id @default(uuid())
  childId     String               @map("child_id")
  type        String                                       // daily | career | wellbeing | learning | self | career_lab | voice
  ageGroup    String               @map("age_group")       // boshlangandagi snapshot
  day         String                                       // Toshkent kuni YYYY-MM-DD
  status      KelajakSessionStatus @default(STARTED)
  questionIds String[]             @map("question_ids")    // tartib bilan snapshot
  total       Int
  result      Json?                                        // yakunda: kodlar va ballar (matn emas, §5)
  scoringVersion Int?              @map("scoring_version")
  startedAt   DateTime             @default(now()) @map("started_at")
  completedAt DateTime?            @map("completed_at")
  updatedAt   DateTime             @updatedAt @map("updated_at")
  child   Child           @relation(fields: [childId], references: [id], onDelete: Cascade)
  answers KelajakAnswer[]
  @@index([childId, type, day])
  @@index([childId, status, completedAt(sort: Desc)])
  @@map("kelajak_sessions")
}

model KelajakAnswer {
  id         String   @id @default(uuid())
  sessionId  String   @map("session_id")
  questionId String   @map("question_id")
  position   Int
  value      Int?                                // shkala qiymati
  textEnc    String?  @map("text_enc")           // ochiq javob, SchoolCryptoService bilan shifrlangan
  answeredAt DateTime @default(now()) @map("answered_at")
  updatedAt  DateTime @updatedAt @map("updated_at")
  session  KelajakSession  @relation(fields: [sessionId], references: [id], onDelete: Cascade)
  question KelajakQuestion @relation(fields: [questionId], references: [id], onDelete: Restrict)
  @@unique([sessionId, questionId])
  @@index([questionId])
  @@map("kelajak_answers")
}
```

`Child` modeliga faqat relation maydoni (`kelajakSessions KelajakSession[]`) qo'shiladi; `children` jadvali o'zgarmaydi.

Migratsiyalar (ikkalasi faqat qo'shuvchi):
1. `20261021090000_kelajak_core` — enum, uch jadval, indekslar, FK.
2. `20261021090100_kelajak_question_bank` — `scripts/kelajak/build-bank-migration.ts` yaratadigan SQL:
   - `INSERT … ON CONFLICT ("external_id") DO NOTHING`;
   - id `externalId`dan deterministik (UUIDv5 shakli, prefiks `parvoz-kelajak:`);
   - `active`, `reverse`, `review_note` va scoring teglari (`signal`, `riasec`) ko'rib chiqish qarorlarining MUZLATILGAN nusxasidan (`prisma/data/kelajak/review-overrides.20261021090100.json`), `required` esa §3 qoidasidan olinadi;
   - spec testi bank JSON'i va muzlatilgan nusxaning sha256'ini tekshiradi va faylni ulardan qayta yaratib, baytma-bayt solishtiradi (278 qator).
   - Qo'llangan migratsiya qayta yozilmaydi: keyingi ko'rib chiqish qarorlari `review-overrides.json`ga (jonli fayl) yoziladi va faqat import CLI (`--update`) yoki admin orqali bazaga yetadi.

Qayta ishlatiladigan import CLI:

```
npx tsx scripts/kelajak/import-bank.ts <fayl.json> [--update] [--dry-run] [--overrides <fayl>] [--overwrite-admin-edits]
```

- Bir xil parser ishlatiladi; upsert `externalId` bo'yicha. `--update`siz mavjud savollar o'tkazib yuboriladi. Qarorlar standart holda `review-overrides.json`dan.
- Hisobot: o'qildi, valid, xato (ro'yxat), fayldagi dublikat, yaratildi, yangilandi, o'tkazib yuborildi, bloklangan, admin tahrirlagan; yaxlitlik va boshqa ogohlantirishlar.
- Javob berilgan savolning `answerType`, `options`, `category`, `ageGroup`, `scoring` va `reverse` maydonlari `--update` bilan ham o'zgarmaydi — admin PATCH bilan YAGONA ro'yxat (`LOCKED_WHEN_ANSWERED`): profil va signal xom javoblardan joriy savol ma'lumoti bilan qayta hisoblanadi, shuning uchun RIASEC o'lchami yoki qutblilik almashsa butun tarix qayta talqin qilinardi.
- Admin yaratgan (`createdBy`) yoki tahrirlagan (audit jurnalida `kelajak.question.update`) savol `--update` bilan ham qayta yozilmaydi — admin matn tuzatishi, faollashtirishi yoki Q090 kabi o'zgartirishi keyingi importda yo'qolmasin. Ataylab yozish kerak bo'lsa — `--overwrite-admin-edits` (javob bloklari baribir amal qiladi). Har holat hisobotning "Ogohlantirishlar" bo'limida maydonlari bilan chiqadi; `--dry-run` bilan oldindan ko'rish mumkin.

## 3. Domen qoidalari (`backend/src/modules/kelajak/domain/`, sof funksiyalar, unit test bilan)

- **Yosh** (`age.ts`):
  - `birthDate` bo'lsa, Toshkent bugungi kuni bo'yicha to'liq yosh hisoblanadi (tug'ilgan kun hali kelmagan bo'lsa bir kam). Aks holda `age` (1–25) olinadi. Ikkalasi ham bo'lmasa — `null`.
  - **`?? 8` kabi fallback ISHLATILMAYDI.**
  - Guruh: 7–9 → `7-9`, 10–12 → `10-12`, 13–15 → `13-15`, 16–18 → `16-18`; boshqa yosh — `null`.
  - Holat: `OK` | `AGE_REQUIRED` | `AGE_OUT_OF_RANGE`.
- **Majburiylik:** shkala turlari `required=true`. `career_lab_5` (refleksiya — bola o'sha topshiriqni bajarmagan bo'lishi mumkin) va `text` (JSON izohi: "ixtiyoriy") `required=false`. `text` savoli hech qachon majburiy bo'lmaydi: parser `required: true`ni rad etadi (bola ochiq matn yozishga majburlanmaydi).
- **Test turlari** (`catalog.ts`, `KELAJAK_TESTS` — savollar soni faqat shu konfiguratsiyada):

  | type | count | kategoriyalar | qoida |
  |---|---|---|---|
  | `daily` | 10 | `career_lab` va `child_voice`dan tashqari hammasi | aylanma, kategoriyadan ≤2 |
  | `career` | 20 | `career_interest` (hammasi) + `career_planning` | qiziqish savollari to'liq (RIASEC qamrovi) |
  | `wellbeing` | 8 | `wellbeing` (hammasi) + `safety` (aylanma) | |
  | `learning` | 10 | `learning`, `school_quality`, `teacher_relation` | aylanma, kategoriyadan ≤4 |
  | `self` | 10 | `social_self`, `personal_traits`, `parent_communication` | aylanma, kategoriyadan ≤4 |
  | `career_lab` | 5 | `career_lab` | ixtiyoriy javoblar |
  | `voice` | 3 | `child_voice` | ixtiyoriy ochiq javob |

  - Har tur Toshkent kuni bo'yicha **kuniga bitta** sessiya. `POST /kelajak/sessions` bugungi sessiyani qaytaradi (yangi, davom etayotgan yoki yakunlangan).
  - O'tgan kunlardagi yakunlanmagan sessiyalar `ABANDONED` bo'ladi — qaysi endpoint birinchi chaqirilmasin: `POST` (boshqa sessiya), `GET /sessions/:id` (yopiq ko'rinadi), `PUT` javob va `complete` (409 `SESSION_CLOSED`). Kechki 23:55 da boshlangan test ertasi kuni davom ettirilmaydi (imtiyozli vaqt yo'q).
  - Kun ichida yosh guruhi o'zgarsa (tug'ilgan sana tahrirlangan), bugungi ochiq sessiya `ABANDONED` bo'ladi va yangi guruhdan qayta tanlanadi; yakunlangan sessiya o'z guruhi bilan qoladi.
  - Yakunlash uchun majburiy savollarning hammasi va **kamida bitta javob** kerak — faqat ixtiyoriy savolli test (Career Lab, ochiq fikr) ham bo'sh holda yakunlanmaydi.
- **Tanlash** (`picker.ts`):
  - Nomzodlar: faol savollar, `ageGroup` = sessiya guruhi, kategoriya turga mos.
  - Tartib: oldin hech javob berilmaganlar, keyin eng uzoq vaqt oldin javob berilganlar. Teng holatda urug'li aralashtirish (urug' = kun + tur + bola id).
  - Kategoriya chegarasi saqlanadi; "hammasi" kategoriyalari birinchi kiritiladi.
  - Yakuniy tartib: kategoriya tartibi (JSON'dagi), ichida tanlov tartibi; `text` savollar oxirida.
  - Boshqa yosh guruhining savoli **hech qachon** aralashmaydi; bu e2e bilan tekshiriladi. Himoya: savol keyin boshqa guruhga o'tkazilgan bo'lsa (admin), eski sessiyadagi javob 400 `QUESTION_NOT_IN_SESSION`; admin esa bugungi ochiq sessiyadagi savolning tuzilmasini o'zgartira olmaydi (§6).
  - `SCHOOL_DATA_KEY` sozlanmagan bo'lsa ochiq (`text`) savollar tanlanmaydi va overview'da `voice` testi ko'rsatilmaydi (ochiq javobni shifrlab saqlab bo'lmaydi).
- **Ball** (`scoring.ts`, `SCORING_VERSION = 1`):
  - Har javob 0–100 ga keltiriladi: `(v - min) / (max - min) * 100`; `reverse` bo'lsa `100 - x`.
  - Kategoriya bali — o'rtacha. RIASEC o'lcham bali — `career_interest` savollari o'rtachasi.
  - Top-3: ball kamayishi bo'yicha, tenglikda javoblar soni ko'pi, keyin R-I-A-S-E-C tartibi. Faqat ≥50 bo'lgan o'lchamlar; `reliable` — har top o'lchamda ≥2 javob.
  - Yo'nalish tavsiyasi (`insights.interests` va Career Lab "keyingi sinash") **faqat `reliable` bo'lsa** — bitta kunlik javobdan yo'nalish tavsiya qilinmaydi; ballar (`interests.dimensions`) baribir ko'rinadi.
  - **Kumulyativ profil:** oxirgi 180 kundagi YAKUNLANGAN sessiyalarda har savolning eng so'nggi javobi. Kunlik aralash savollar shu orqali vaqt bilan to'liq profilga yig'iladi. `answeredQuestions` — shulardan bolaning JORIY yosh guruhidagi faol shkala savollariga berilganlari (`availableQuestions` bilan solishtiriladi; guruh almashganda 100% dan oshmaydi). Ballar esa guruh filtrisiz hisoblanadi.
  - **Kuchli tomon:** profil kategoriyasi ≥70 va ≥2 javob (`learning`, `school_quality`, `teacher_relation`, `social_self`, `career_planning`, `parent_communication`, `personal_traits`).
  - **Rivojlantirish mumkin:** shu kategoriyalar <50 va ≥2 javob; qo'shimcha `safety_rules` ("Xavfsizlik qoidalari") — `knowledge` savollari o'rtachasi <50 va ≥2 javob (signal emas, faqat maslahat).
  - **Kuchli fanlar:** Kelajak bankida fan maydoni yo'q (Q061, Q067, Q072, Q073 — nofaol). Fan bo'yicha kuchli tomon Growth'da allaqachon hisoblanadi va ko'rsatiladi (`learning-stats.ts` `strongSubject`, haftalik ota-ona xulosasi) — Kelajak uni takrorlamaydi. Keyingi bosqich: `InsightsView`/`ParentSummaryView`ga `strongSubjects` (Growth statistikasidan faqat o'qish, yangi jadvalsiz) qo'shish.
  - **Career Lab:** xulosa normallashtirilgan balldan (shkala qanday bo'lmasin): ≥60 — yoqdi, ≤40 — yoqmadi, oraliq — betaraf (`career_lab_5`: 4–5 / 3 / 1–2; `yes_no`: "Ha" — yoqdi). Shu sababli Q212 kabi savolni `yes_no`ga o'tkazish xulosani buzmaydi.
    - RIASEC kodi ma'lumotda — `scoring.riasec` (§1); faoliyatning qisqa nomi `career-lab.ts`da (xaritada yo'q savol nomi — savol matni). Umumiy savollar (Q193, Q208, Q210–Q212) kodsiz.
    - "Keyingi sinash": top qiziqish kodiga mos (`scoring.riasec`, admin qo'shgani ham), hali baholanmagan faoliyat; bo'lmasa yoqqan faoliyatni chuqurlashtirish. Tavsiyada faoliyat `externalId`si qaytadi (§4 `next[].externalId`).
    - Keyingi bosqich (hali yo'q): qiziqish → topshiriq → sinov → refleksiya zanjiri uchun qo'shuvchi `kelajak_career_lab_tasks` (bolaga berilgan topshiriq, `externalId` bilan bog'langan refleksiya). Hozir Career Lab testi yosh guruhidagi faoliyatlarni ixtiyoriy baholashni so'raydi (bajarmagani o'tkazib yuboriladi).
  - **Qo'llab-quvvatlash signali** (`wellbeing` + `safety`, faqat `distress` savollari — §1 "Signal turi"):
    - Normallashtirilgan ball ≤25 bo'lgan holat javobi tashvish hisoblanadi; xavfsizlik bilimi (`knowledge`) savollari signalga kirmaydi.
    - Sessiya darajasi: ≥2 tashvish → `support`, 1 → `watch`, 0 → `none`.
    - Manba (oxirgi 30 kun): eng so'nggi `wellbeing` testi — to'liq tekshiruv — tayanch; undan oldingi sessiyalar hisobga olinmaydi, keyingilari (kunlik savollar) darajani faqat OSHIRADI, hech qachon tushirmaydi (1–2 ta kunlik javob 8 savollik tekshiruvdagi `support`ni o'chirib yubormasin). Wellbeing testi bo'lmasa — oynadagi barcha sessiyalarning eng yuqori darajasi. Sohalar — hisobga olingan sessiyalardagi barcha tashvishlar; `day` — shu darajaga olib kelgan eng so'nggi sessiya kuni.
    - Sohalar faqat kategoriya darajasida beriladi (`wellbeing`, `safety`). **Raqam ham, savol ham ko'rsatilmaydi.**
  - **Keyingi tavsiya** (≤2 ta):
    - `career_interest` qamrovi 80% dan kam bo'lsa → `career` testi;
    - 14 kunda wellbeing sessiyasi bo'lmasa → `wellbeing` testi;
    - mos Career Lab faoliyati bo'lsa → shu faoliyat;
    - aks holda → "ertaga yana".
- **Matnlar** (`texts.ts`, uz/ru/en — barcha 3 frontend uchun yagona manba):
  - kategoriya nomlari, test nomlari va tavsiflari;
  - RIASEC yo'nalishlari va namunaviy sohalar;
  - kuchli tomon va rivojlanish yorliqlari, maslahatlar;
  - qo'llab-quvvatlash xabarlari va ogohlantirish (disclaimer).

  - ochiq fikr va farovonlik testlari tavsifi bolaga kim nimani ko'rishini aytadi: ota-ona javoblarni emas, faqat umumiy xulosani ko'radi; ochiq fikrni hech kim o'qib javob qaytarmaydi — yordam kerak bo'lsa ishonchli katta yoki SOS tugmasi.

  **Siyosat:** kasb bo'yicha qat'iy hukm yo'q. Taqiqlangan iboralar (unit test barcha matnlarni tekshiradi): uz `bo'lishing kerak` / `bo‘lishing kerak`, `mos ekansan`, `100%`, `tashxis`(ijobiy ma'noda); ru `должен стать`, `тебе нужно стать`, `100%`; en `you should become`, `you must become`, `100%`.

  Namuna: "Sizda texnologiya va muammolarni yechishga qiziqish yuqori. Quyidagi yo'nalishlarni sinab ko'rishingiz mumkin: dasturlash, muhandislik, ma'lumotlar tahlili, texnologik loyihalar."

## 4. API — bola ilovasi (`CHILD` token), `/api/kelajak`

Xato formati mavjud loyiha bilan bir xil: `{ statusCode, message, code }`.

| Metod | Yo'l | Body | Javob / xatolar |
|---|---|---|---|
| GET | `/kelajak/overview` | — | `OverviewView` |
| POST | `/kelajak/sessions` | `{ type }` | `SessionView` (bugungi). 400 `UNKNOWN_TYPE`, 409 `AGE_REQUIRED`, 409 `AGE_OUT_OF_RANGE`, 404 `NO_QUESTIONS` |
| GET | `/kelajak/sessions/:id` | — | `SessionView`. 404. O'tgan kunda boshlangan ochiq sessiya `ABANDONED` bo'lib qaytadi. |
| PUT | `/kelajak/sessions/:id/answers/:questionId` | `{ value?: int, text?: string }` | `AnswerView`. 400 `QUESTION_NOT_IN_SESSION` (savol sessiyada yo'q yoki boshqa yosh guruhiga o'tkazilgan), 400 `INVALID_ANSWER`, 409 `SESSION_CLOSED` (yopiq yoki o'tgan kunda boshlangan sessiya — u shu zahoti `ABANDONED` bo'ladi), 503 `NOT_CONFIGURED` (ochiq matn, server shifrlash kaliti sozlanmagan — odatda bunday savol tanlanmaydi, §3). Faqat sessiya bugun ochiq bo'lsa (STARTED/IN_PROGRESS) javobni o'zgartirish mumkin ("orqaga" ishlaydi). `text: ""` javobni o'chiradi. Matn ≤1000 belgi. |
| POST | `/kelajak/sessions/:id/complete` | — | `SessionView` (`result` bilan), idempotent. 400 `UNANSWERED` (+`remaining: string[]` — majburiy javobsizlar; birorta javob yo'q bo'lsa — barcha savollar), 409 `SESSION_CLOSED` |
| GET | `/kelajak/progress` | — | `ProgressView` |
| GET | `/kelajak/results?before=&limit=` | — | `{ items: SessionSummaryView[], nextBefore: string \| null }` |

```ts
type L = { uz: string; ru?: string; en?: string };
type AgeView = { status: 'OK' | 'AGE_REQUIRED' | 'AGE_OUT_OF_RANGE'; age: number | null; ageGroup: string | null };

interface OverviewView {
  age: AgeView;
  tests: Array<{                      // age.status !== 'OK' bo'lsa []; savoli yo'q tur ko'rsatilmaydi (kalitsiz serverda voice)
    type: string; title: L; description: L; questionCount: number; estimatedMinutes: number;
    today: { status: 'NEW' | 'STARTED' | 'IN_PROGRESS' | 'COMPLETED'; sessionId: string | null };
  }>;
  categories: Array<{ id: string; name: L; order: number }>;
  profile: ProfileView | null;        // hali yakunlangan sessiya bo'lmasa null
}

interface SessionView {
  id: string; type: string; title: L; ageGroup: string; day: string;
  status: 'STARTED' | 'IN_PROGRESS' | 'COMPLETED' | 'ABANDONED';
  startedAt: string; completedAt: string | null; total: number; answeredCount: number;
  questions: Array<{
    id: string; externalId: string; category: string; categoryName: L; text: L;
    answerType: string; options: Array<{ value: number; label: L }>; required: boolean;
    maxLength: number | null;                              // text uchun 1000
    // follow_up — operator uchun ichki izoh (masalan, "refleksiya so'ralsin"), bolaga YUBORILMAYDI (faqat admin).
  }>;
  // Faqat bolaga. Sessiya ochiq (STARTED/IN_PROGRESS) bo'lsagina `text` va wellbeing/safety `value`si
  // qaytadi ("orqaga" uchun); yopiq sessiyada ular null — shu bolaga keyin ulangan qurilma ham o'qiy olmaydi.
  answers: Array<{ questionId: string; value: number | null; text: string | null }>;
  result: ResultView | null;
}

interface AnswerView { questionId: string; value: number | null; text: string | null; sessionStatus: string; answeredCount: number }

interface CategoryScoreView { category: string; name: L; score: number; answered: number }
interface InterestsView { dimensions: Array<{ code: 'R'|'I'|'A'|'S'|'E'|'C'; name: L; score: number; answered: number }>; top: string[]; reliable: boolean }
interface InsightsView {
  strengths: Array<{ key: string; title: L }>;
  interests: Array<{ code: string; title: L; body: L; suggestions: L[] }>;   // top yo'nalishlar, qat'iy hukmsiz; faqat interests.reliable bo'lsa, aks holda []
  likedDirections: Array<{ externalId: string; activity: L; code: string | null; rating: number }>;   // rating — xom qiymat
  triedDirections: Array<{ externalId: string; activity: L; code: string | null; rating: number; verdict: 'liked'|'neutral'|'disliked' }>;
  growthAreas: Array<{ key: string; title: L; tip: L }>;                    // key: ballanadigan kategoriya yoki 'safety_rules'
  support: { level: 'none' | 'watch' | 'support'; message: L } | null;      // bolaga raqamsiz, mehribon matn
  next: Array<{ kind: 'take_test' | 'career_lab' | 'come_back'; testType: string | null; externalId: string | null; title: L; body: L }>; // externalId — Career Lab faoliyati
}
interface ResultView {                // sessiya natijasi: sessiya ballari + yakundagi kumulyativ profil bo'yicha insightlar
  answered: number; total: number;
  categories: CategoryScoreView[];    // faqat ballanadigan kategoriyalar; wellbeing/safety YO'Q
  interests: InterestsView | null;
  insights: InsightsView;
  disclaimer: L;
}
interface ProfileView { updatedAt: string; answeredQuestions: number; availableQuestions: number; categories: CategoryScoreView[]; interests: InterestsView | null; insights: InsightsView; disclaimer: L } // answeredQuestions — joriy guruhning faol shkala savollaridan
interface SessionSummaryView { id: string; type: string; title: L; day: string; status: string; completedAt: string | null; answered: number; total: number }
interface ProgressView {
  sessionsCompleted: number; firstCompletedAt: string | null; lastCompletedAt: string | null;
  categories: Array<{ category: string; name: L; latest: number; previous: number | null; delta: number | null; points: Array<{ day: string; score: number }> }>; // wellbeing/safety yo'q, ≤12 nuqta
  interests: Array<{ code: string; name: L; latest: number; previous: number | null; delta: number | null }>;
  improved: string[]; interestsRising: string[];   // delta ≥ 10
  history: SessionSummaryView[];                   // oxirgi 20
}
```

`result` ustunida faqat kodlar va ballar saqlanadi:

```
{ version, scores: { categories, interests, careerLab, support }, insightCodes }
```

Mahalliylashtirilgan matnlar o'qishda `texts.ts`dan qo'shiladi. Shunda matn tahrirlansa, eski natijalar ham yangi matn bilan ko'rinadi.

## 5. API — ota-ona (`PARENT` token, bola egasi): `GET /api/children/:childId/kelajak/summary`

```ts
interface ParentDirectionView { activity: L; code: string | null }   // savol id'si va xom reytingsiz
interface ParentSummaryView {
  age: AgeView; sessionsCompleted: number; lastCompletedAt: string | null;
  categories: CategoryScoreView[];            // wellbeing/safety va parent_communication YO'Q; faqat answered ≥ 2
  interests: InterestsView | null;
  insights: {
    strengths: InsightsView['strengths'];     // parent_communication yo'q
    interests: InsightsView['interests'];
    likedDirections: ParentDirectionView[];
    triedDirections: Array<ParentDirectionView & { verdict: 'liked' | 'neutral' | 'disliked' }>;
    growthAreas: InsightsView['growthAreas']; // parent_communication yo'q
    next: InsightsView['next'];               // externalId har doim null (faoliyat nomi matnda)
  };
  support: { level: 'watch' | 'support'; areas: Array<{ key: string; name: L }>; day: string; guidance: L } | null; // 'none' → null
  progress: { categories: ProgressView['categories']; interests: ProgressView['interests'] }; // kategoriyalar — yuqoridagi filtr bilan
  disclaimer: L;
}
```

**Maxfiylik:**
- ota-onaga savol darajasidagi javoblar, ochiq matnlar va wellbeing/safety raqamlari berilmaydi;
- bitta javobli kategoriya ham ko'rsatilmaydi (u aynan shu javob bo'lardi): kategoriya va progress nuqtasi kamida 2 javobdan;
- `parent_communication` ("qiyin vaziyatda ota-onangdan yordam so'rash xavfsiz tuyuladimi?" kabi) ota-onaga umuman chiqmaydi — bola halol javob bersin; bolaning o'ziga ko'rinadi. Bunday past javoblarni maktab psixologiga signal qilish — keyingi bosqich (maktab kanali yo'q, ota-onaga yo'naltirilmaydi);
- Career Lab — faoliyat nomi va xulosa, savol id'si va xom reyting yo'q;
- yopiq sessiyaning ochiq matni va wellbeing/safety qiymatlari bola API'sida ham qaytmaydi (§4) — ota-ona qayta ulash (repair QR / oila kodi) orqali yangi bola qurilmasi yaratsa ham ularni o'qiy olmaydi;
- bola "Uzish va ma'lumotlarimni o'chirish" (`DELETE /users/me`) qilsa, uning barcha Kelajak sessiyalari, javoblari (ochiq matn bilan) va natijalari ham o'chadi (bola profili ota-onada qoladi);
- begona ota-ona — 403, bola tokeni — 403, bola yo'q — 404.

## 6. Admin (`/api/admin/kelajak`, `AdminJwtAuthGuard` + `PermissionsGuard`, `@Permissions('manage_learning')`)

| Metod | Yo'l | Izoh |
|---|---|---|
| GET | `questions?page&limit(≤100)&category&ageGroup&active&answerType&sourceType&q` | `{ items: AdminQuestionView[], pagination: { page, limit, total, totalPages } }` |
| GET | `questions/:id` | `AdminQuestionView` |
| POST | `questions` | Yaratish. `externalId` ixtiyoriy (`^[A-Z0-9-]{3,40}$`, unikal; `PARVOZ-` prefiksi bank uchun band — 400 `INVALID_QUESTION`); berilmasa `ADMIN-` + 8 belgi. 409 `DUPLICATE_EXTERNAL_ID` |
| PATCH | `questions/:id` | `answerCount > 0` yoki savol bugungi ochiq sessiya snapshot'ida bo'lsa faqat `text`, `notes`, `reviewNote`, `followUp`, `required`, `active` o'zgaradi; aks holda 409 `QUESTION_IN_USE` (+`fields`). Tekshiruv va yozish bitta tranzaksiyada, savol qatori `FOR UPDATE` bilan qulflanadi (bolaning javobi `FOR SHARE` bilan navbat kutadi). |
| GET | `stats` | `{ total, active, inactive, needsReview, byCategory: [{category, name, total, active}], byAgeGroup: [{ageGroup, total, active}], byAnswerType: [...], sessions: { total, completed, completedLast7Days } }` |

```ts
interface AdminQuestionView {
  id: string; externalId: string; category: string; categoryName: L; ageGroup: string; text: L;
  answerType: string; options: Array<{ value: number; label: L }>; scoring: object | null;
  reverse: boolean; required: boolean; followUp: string | null; notes: string | null; reviewNote: string | null;
  sourceType: string; sourceName: string; sourceVersion: string; active: boolean;
  answerCount: number; createdAt: string; updatedAt: string;
}
```

- **Validatsiya:** import bilan bir xil parser.
  - kategoriya — 12 tadan biri; yosh — 4 tadan biri; `answerType` — ma'lum turlar;
  - variantlar 2–10 ta, qiymatlari butun va unikal, yorliq ≤120; `text` turida variant yo'q va `required: true` rad etiladi;
  - `text.uz` 1–500 belgi; `followUp` ≤500, `notes` / `reviewNote` ≤1000;
  - `scoring` — oq ro'yxat: `method` (`simple_sum` | `dimension_sum` | `support_signal` | `reflection_rating`), `dimension`, `min`, `max` (variantlar bilan mos), `interpretation`, `direction`, `note`, `signal` (`distress` | `knowledge`), `riasec` (R…C); noma'lum kalit yoki ichma-ich qiymat — 400; `career_interest` uchun `dimension` RIASEC kodi majburiy.
- **Audit:** `AdminAuditService.log` (`kelajak.question.create` / `update`).
- O'chirish yo'q: nofaol qilish yumshoq o'chirish o'rnini bosadi.

## 7. Frontendlar

- **admin-web:**
  - `(dashboard)/kelajak/page.tsx` — "Kelajak savollari"; sidebar'ning "Platforma" bo'limida.
  - Sahifa: statistika kartalari (jami/faol/nofaol/ko'rib chiqish, yosh guruhlari, kategoriyalar jadvali, javob turlari, sessiyalar); filtrlar (kategoriya, yosh, holat, javob turi, manba, qidiruv); jadval; faollik `Switch`i.
  - Dialoglar: ko'rish/tahrirlash va "Yangi savol". Javob berilgan savolda bloklangan maydonlar tushuntirish bilan ko'rsatiladi.
  - Ball o'lchami tanlovi kategoriyaga bog'liq: `career_interest` — RIASEC yo'nalishi (majburiy), `career_lab` — faoliyat yo'nalishi (ixtiyoriy), `wellbeing`/`safety` — signal turi (holat / xavfsizlik bilimi). Ochiq javob har doim ixtiyoriy; `followUp` — "ichki izoh", bolaga ko'rsatilmaydi.
  - Tahrir oynasi PATCH'ni forma to'ldirilgan holatga nisbatan hisoblaydi (boshqa admin kiritgan o'zgarish eskirgan ro'yxat qatori bilan qaytarilmaydi) va savol shu orada o'zgargan bo'lsa ogohlantiradi.
  - `manage_learning` frontend ruxsatlar katalogiga ham qo'shiladi.
- **bola ilovasi** — `lib/features/kelajak/`:
  - Bosh sahifada `TodayTestsCard`dan keyin `KelajakTodayCard`. "Bugungi testlar" qatorida kunlik savollar holati ko'rinadi.
  - `/kelajak` hub: testlar ro'yxati va kategoriyalar.
  - `/kelajak/session`: savol, variantlar, progress, "Orqaga" va "Keyingi" tugmalari. Majburiy savolsiz "Keyingi" o'chiq; ixtiyoriy savolda "O'tkazib yuborish".
  - Natija: "Bugungi natijangiz" — kuchli tomonlar, qiziqishlar, yoqqan yo'nalishlar, rivojlantirish, keyingi tavsiya.
  - "Rivojlanish" (`/progress`) sahifasiga "Kelajak profilim" bo'limi; batafsil sahifa `/kelajak/progress`.
  - `AGE_REQUIRED` bo'lsa mavjud profil (yosh) tahrirlash oqimiga yo'naltiriladi.
  - Gradient, binafsha rang va ortiqcha animatsiya yo'q; mobile-first.
- **ota-ona ilovasi** — `lib/features/kelajak/`:
  - o'z-o'zini yashiradigan `KelajakDashboardCard` (Growth/School kartasidan keyin);
  - `KelajakScreen(childId)`, yo'l `/kelajak/:childId`: qiziqishlar, kuchli tomonlar, rivojlanish, Career Lab, qo'llab-quvvatlash signali (ehtiyotkor matn bilan), progress va disclaimer.

## 8. Testlar

- **Backend unit:**
  - yosh: chegara holatlari va Toshkent kuni;
  - parser: 278/278 savol valid, buzilgan yozuvlar rad etiladi, scoring oq ro'yxati, yaxlitlik ogohlantirishlari, bank sha256;
  - migratsiya: muzlatilgan kirishlar sha256 va fayl generator chiqishi bilan aynan bir xil;
  - picker: faqat o'z guruhi, chegaralar, takrorlanmaslik, determinizm, `career` qamrovi;
  - scoring: teskari savol, notekis RIASEC, top-3 tengligi, career lab (normallashtirilgan xulosa), signal (faqat holat savollari, wellbeing tayanchi), kuchli tomon, rivojlanish va `safety_rules`;
  - import rejasi: bloklar (scoring/reverse ham), admin tahrirlagan savol himoyasi;
  - mapper: ota-ona signal / Career Lab / kategoriya filtri, yopiq sessiya javoblari;
  - matn siyosati.
- **Backend e2e** (lokal `*_test` DB):
  - CASE 1–4: 8, 11, 14 va 17 yosh (`birthDate` va `age` orqali) → faqat mos guruh savollari;
  - `AGE_REQUIRED` va `AGE_OUT_OF_RANGE`;
  - asosiy oqim: start → javob → javobni o'zgartirish → complete → natija → idempotent complete (dublikat yo'q);
  - qayta `POST` (refresh) bir xil sessiyani javoblari bilan qaytaradi;
  - progress va tarix yangilanadi; kunlik savollar ertasi kuni takrorlanmaydi;
  - ochiq matn shifrlangan holda saqlanadi va ota-onaga chiqmaydi; yopiq sessiyada matn va wellbeing/safety qiymatlari qayta ulangan qurilmaga ham qaytmaydi; bola o'z ma'lumotini o'chirsa Kelajak ham o'chadi; kalitsiz serverda `voice` yo'q;
  - o'tgan kungi sessiyaga javob / yakunlash — 409; parallel `POST` — bitta sessiya; kun ichida yosh guruhi o'zgarishi;
  - ota-ona ruxsatlari; signal `none` → null, `watch`; `parent_communication` va 1 javobli kategoriya yashirin;
  - admin: ruxsatsiz → 403; CRUD; `career_interest` admin-web payload shakli bilan; `PARVOZ-` band; javob berilgan va bugungi ochiq sessiyadagi savolni bloklash; nofaol savol tanlanmaydi.
- **admin-web:** `src/components/kelajak/question-form.test.ts` (Node test runner: `npx tsx --test src/components/kelajak/question-form.test.ts`) — RIASEC/signal/Career Lab teglari, payload'lar, chegaralar, ro'yxat keshi.
- **Ilovalar:** model parsing, repository (soxta HTTP), session holat mashinasi (orqaga va oldinga, majburiy savol), widget testlari, tarjima pariteti.

## 9. Ishga tushirish (deploy) ro'yxati

- `SCHOOL_DATA_KEY` (base64, 32 bayt) production'da sozlanishi SHART: busiz ochiq javobni shifrlab bo'lmaydi — `voice` testi ko'rsatilmaydi, ochiq savollar tanlanmaydi, eski ochiq sessiyaga matn yuborilsa 503 `NOT_CONFIGURED`.
- `npx prisma migrate deploy` — `20261021090000_kelajak_core` va `20261021090100_kelajak_question_bank` (qo'shuvchi; bank savollari `ON CONFLICT DO NOTHING`).
- Keyingi ko'rib chiqish qarorlari (`review-overrides.json`) yoki bank versiyasi — avval `import-bank.ts <fayl> --update --dry-run`, hisobotdagi "Bloklangan" va "Admin tahrirlagan" bo'limlarini ko'rib, keyin `--dry-run`siz.
- Mazmun egasi qarori kutilmoqda: Q249 ("Hozir seni bezovta qilayotgan biror narsa bormi?") va Q250 (kattalar bilishi kerak bo'lgan muammo) bolani murojaatga undaydi, lekin ochiq fikrni hech bir katta o'qimaydi; matn bolaga buni aytadi va SOS'ga yo'naltiradi. Ularni nofaol qilish yoki maktab psixologi ko'rib chiqadigan kanal qo'shish — mazmun egasi va xavfsizlik bo'yicha qaror (avtomatik qo'llanmagan).

> **2026-10-21, egasi talabi — shkala yorliqlari.** Savollar "-mi?" shaklida bo'lgani uchun "To'g'ri / To'g'ri emas" javobi o'zbekchada mos emas edi. `likert_5` → "Yo'q / Ko'proq yo'q / Ba'zan / Ko'proq ha / Ha", `interest_4` → "Yo'q / Unchalik emas / Ha / Ha, juda" (`review-overrides.json` `scaleLabels`, migratsiya `20261021130000_kelajak_scale_labels`). Qiymatlar, ball va oldingi javoblar o'zgarmaydi; JSON fayl o'zgarmaydi.
