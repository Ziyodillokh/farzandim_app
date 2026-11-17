# Kelajak API fixture'lari — bola ilovasi

Bu fayllar backend qaytargan haqiqiy javoblardan olingan. Manba: `farzandim_app-qbank`, PR #12, `backend/src/modules/kelajak`. Ular qo'lda yozilmagan.

- **Qanday olingan.** Vaqtinchalik e2e spec (`zz-kelajak-fixture-dump`, keyin o'chirilgan) ishga tushirilgan. U production quvuridagi Nest/Fastify ilovasi, lokal `*_test` bazasi va `seedKelajakBank` (278 savol, migratsiya qarorlari bilan) ustida ishladi.
- **Sana.** Snapshot 2026-10-21 (Toshkent kuni) holatida. Barcha bolalar 11 yoshda (`10-12` guruhi). `SCHOOL_DATA_KEY` sozlangan, shuning uchun `voice` testi ham bor.
- **Fayl tarkibi.** Har faylda faqat javob body'si bor (`JSON.stringify(body, null, 2)`). Xato fayllarining nomida HTTP status ham yozilgan.
- **Barqaror id'lar.** Savol `id`lari deterministik: UUIDv5 `externalId`dan olinadi. Ular bank o'zgarmaguncha o'zgarmaydi.
- **O'zgaruvchan qiymatlar.** Sessiya id'lari va vaqtlar tasodifiy. Testlar haqiqiy "bugun"ga tayanmasligi kerak: `day` va `completedAt` qat'iy sanalar.
- **Xato formati.** `{ statusCode, message, code }` (`UNANSWERED`da qo'shimcha `remaining`). `message` inglizcha va UI uchun emas, shuning uchun `code`dan foydalaning.

## Ssenariylar

| Bola | Ssenariy |
|---|---|
| **A — "Bobur"** | Yangi bola. Hamma 7 tur boshlangan, kunlik savollarda qisman javob bor, ochiq fikr yozilgan, Career Lab'da 1 javob bilan yakunlangan. |
| **B — "Dilnoza"** | Yoshi ham, tug'ilgan sanasi ham yo'q. Keyin 19 yosh qilib qo'yilgan. |
| **C — "Aziz"** | Boy profil, 7 sessiya, 2026-10-17 dan 21 gacha (`shiftSessionDays` bilan surilgan). 10-17 kuni `learning` (eng past javoblar) va `self` (eng yuqori). 10-18 kuni `wellbeing` (eng past javoblar → `support`). 10-19 kuni `career` (I va A yuqori, boshqalari past, kasb rejasi yuqori). 10-20 kuni `career_lab` (5/4/3/1, beshinchisi o'tkazilgan). 10-21 kuni `career` (I, A va S yuqori) va `daily` (o'qish kategoriyalari pastroq, qolgani tashvishsiz). |
| **D — "Malika"** | `wellbeing` testida bitta tashvishli javob bor (`watch`). |

`session_complete_*` fayllari yakunlash paytidagi haqiqiy javob. O'sha paytda `day` = 2026-10-21 edi, sessiya keyinroq orqaga surilgan.

## Fayllar

### Overview — `GET /kelajak/overview`
| Fayl | Ssenariy |
|---|---|
| `overview_ok_fresh.json` | A, hali hech narsa boshlanmagan. `age` OK (11, `10-12`), 7 test, hammasida `today.status: NEW`, 12 kategoriya, `profile: null`. |
| `overview_ok_today_mixed.json` | A, oqimlardan keyin. `daily` va `voice` IN_PROGRESS, `career_lab` COMPLETED, qolganlari STARTED. `profile`da 1 javob bor, insight'lar deyarli bo'sh. |
| `overview_ok_with_profile.json` | C, oxirida. `daily` va `career` COMPLETED, qolganlari NEW. To'liq profil: 59/63 javob, kuchli tomonlar, qiziqishlar (A, I, S), yoqqan va sinalgan yo'nalishlar, rivojlantirish, `support: support`, keyingi tavsiya `career_lab`. |
| `overview_age_required.json` | B. `AGE_REQUIRED`, `age`/`ageGroup` null, `tests: []`, `profile: null`. |
| `overview_age_out_of_range.json` | B, 19 yosh. `AGE_OUT_OF_RANGE`, `age: 19`, `tests: []`. |

### Sessiya boshlash — `POST /kelajak/sessions` (A, 200)
Hammasida `status: STARTED`, `answers: []`, `result: null`.

| Fayl | Mazmun |
|---|---|
| `session_start_daily.json` | 10 savol, `interest_4` + `likert_5`, 8 kategoriya. |
| `session_start_career.json` | 19 savol: `career_interest` + `career_planning`. |
| `session_start_wellbeing.json` | 8 savol: `wellbeing` + `safety`. |
| `session_start_learning.json` | 10 savol: `learning`, `school_quality`, `teacher_relation`. |
| `session_start_self.json` | 10 savol: `social_self`, `personal_traits`, `parent_communication`. |
| `session_start_career_lab.json` | 5 savol, `career_lab_5`, hammasida `required: false`. |
| `session_start_voice.json` | 3 savol, `text`, `required: false`, `maxLength: 1000`. |

### Davom etayotgan sessiya — `GET /kelajak/sessions/:id`
| Fayl | Mazmun |
|---|---|
| `session_daily_in_progress.json` | A. 3 ta javob bor (birinchisi "orqaga" qaytib 1 → 4 qilib o'zgartirilgan), `IN_PROGRESS`, `answeredCount: 3`. |
| `session_voice_in_progress.json` | A. Bitta ochiq javob. Sessiya ochiq bo'lgani uchun `text` ko'rinadi. |
| `session_view_wellbeing_closed.json` | C. Yakunlangan wellbeing sessiyasi 10-18 ga surilgandan keyin olingan. Barcha `answers[].value` null (maxfiylik). |

### Javob — `PUT /kelajak/sessions/:id/answers/:questionId` (A, 200)
| Fayl | Mazmun |
|---|---|
| `answer_put_scale.json` | Birinchi javob, `value: 1`. `sessionStatus: IN_PROGRESS`, `answeredCount: 1`. |
| `answer_put_scale_changed.json` | Xuddi shu savol 4 ga o'zgartirilgan ("orqaga"). `answeredCount` 1 bo'lib qoladi. |
| `answer_put_text.json` | Ochiq javob, `value: null`. |
| `answer_put_text_cleared.json` | `text: ""` yuborilgan, javob o'chirildi: `text`/`value` null, `answeredCount: 0`. |

### Yakunlash — `POST /kelajak/sessions/:id/complete` (200)
| Fayl | Mazmun |
|---|---|
| `session_complete_career.json` | C. `insights`: 4 kuchli tomon, `interests` A va I (`reliable`), 4 ta `growthAreas` (`learning`, `school_quality`, `teacher_relation`, `safety_rules`), `support: support`, `next` = `career_lab` (`PARVOZ-Q198`). Career Lab hali qilinmagani uchun `likedDirections`/`triedDirections` bo'sh. |
| `session_complete_daily.json` | C. Eng to'liq natija: hamma `insights` bo'limi to'la, 2 yoqqan va 4 sinalgan yo'nalish (liked, neutral, disliked). Sessiya darajasida `interests: null`, chunki kunlik testga `career_interest` savoli tushmagan. 2 ta javobda `value: null` (yopiq sessiyadagi wellbeing/safety). |
| `session_complete_career_lab.json` | C. 4/5 javob (bittasi o'tkazilgan), reytinglar 5/4/3/1. `result.categories: []`. |
| `session_complete_wellbeing_support.json` | C. `support.level: support`, raqamsiz mehribon xabar bilan. `result.categories: []`. |
| `session_complete_wellbeing_watch.json` | D. `support.level: watch`. |
| `session_complete_minimal.json` | A. Career Lab, 1 javob. Kuchli tomon, qiziqish va rivojlantirish bo'sh, `support: null`. `next` = `take_test` career va wellbeing (bo'sh holat UI uchun). |

### Progress va natijalar
| Fayl | Mazmun |
|---|---|
| `progress_empty.json` | A, hali yakunlangan sessiya yo'q. |
| `progress_multi_day.json` | C, 7 sessiya. `improved`: `school_quality` va `teacher_relation` (0 → 25). `interestsRising`: S (0 → 100). Kategoriyalarda `previous`, `delta` va `points` bor. `learning`da bitta nuqta (`previous: null`). `history`da 7 ta yozuv. |
| `results_empty.json` | `{ items: [], nextBefore: null }`. |
| `results_all.json` | C, 7 ta yozuv, eng yangisi birinchi, `nextBefore: null`. |
| `results_page1_limit2.json` | `?limit=2`. `nextBefore` null emas. |
| `results_page2_limit2.json` | `?limit=2&before=<1-sahifa nextBefore>`. |

### Xatolar
| Fayl | Holat |
|---|---|
| `error_400_unanswered.json` | `daily` 3/10 javob bilan yakunlanmoqchi bo'lingan. `remaining`da 7 id. |
| `error_400_invalid_answer.json` | `value: 9` yuborilgan. |
| `error_400_question_not_in_session.json` | `career` savoli `daily` sessiyasiga yuborilgan. |
| `error_400_unknown_type.json` | `type: "astrology"`. |
| `error_404_session_not_found.json` | Tasodifiy UUID, `code: SESSION_NOT_FOUND`. |
| `error_409_age_required.json` | B, yoshsiz `POST`. |
| `error_409_age_out_of_range.json` | B, 19 yosh. |
| `error_409_session_closed.json` | Yakunlangan Career Lab sessiyasiga `PUT`. |
