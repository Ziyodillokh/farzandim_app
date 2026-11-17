# Kelajak API fixture'lari — ota-ona ilovasi

Bu fayllar backend qaytargan haqiqiy javoblardan olingan: `GET /api/children/:childId/kelajak/summary` (manba: `farzandim_app-qbank`, PR #12). Ular vaqtinchalik e2e spec (`zz-kelajak-fixture-dump`, keyin o'chirilgan) yordamida olingan. Spec production quvuridagi Nest/Fastify ilovasi, lokal test bazasi va 278 savollik bank ustida ishladi.

- **Sana.** Snapshot 2026-10-21 (Toshkent).
- **Fayl tarkibi.** Har faylda faqat javob body'si bor (2 bo'sh joy bilan formatlangan).
- **O'zgaruvchan qiymatlar.** Bola id'lari va vaqtlar tasodifiy.
- **Bola fixture'lari.** Bola tomonidagi fayllar va ssenariylar `farzandim_child/test/features/kelajak/fixtures/README.md`da.

## Fayllar

| Fayl | Ssenariy |
|---|---|
| `parent_summary_empty.json` | 11 yoshli bola, yakunlangan sessiya yo'q. `age` OK, `sessionsCompleted: 0`, `categories: []`, `interests: null`. `insights` ro'yxatlari bo'sh, `next` = `take_test` career va wellbeing. `support: null`, `progress` bo'sh. |
| `parent_summary_age_required.json` | Bolaning yoshi ham, tug'ilgan sanasi ham yo'q. `age.status: AGE_REQUIRED`, `next` = `take_test` wellbeing. |
| `parent_summary_rich_support.json` | Boy profil ("Aziz", 7 sessiya, 2026-10-17 dan 21 gacha; bola README'dagi C ssenariysi). Batafsil quyida. |
| `parent_summary_watch.json` | Bitta wellbeing sessiyasida bitta tashvishli javob bor. `support` = `{ level: watch, areas: [wellbeing], day: 2026-10-21, guidance }`. Qolgan bo'limlar bo'sh, `next` = `take_test` career. |
| `error_403_forbidden.json` | Begona ota-ona so'ragan. Body: `{ statusCode: 403, message, error }`. **`code` maydoni yo'q.** |
| `error_404_child_not_found.json` | Bunday bola yo'q. Body: `{ statusCode: 404, message: "Child not found", error }`. **`code` maydoni yo'q.** |

### `parent_summary_rich_support.json` tarkibi

- **`categories`.** Faqat kamida 2 javobli kategoriyalar. wellbeing, safety va `parent_communication` umuman chiqmaydi.
- **`interests`.** Top yo'nalishlar: A, I, S.
- **`insights`:**
  - **Kuchli tomonlar** — 3 ta (`parent_communication` olib tashlangan).
  - **Rivojlantirish** — 4 ta.
  - **Career Lab yo'nalishlari** — 2 ta yoqqan va 4 ta sinalgan. Ularda `activity` va `code` bor, `externalId` va `rating` yo'q.
  - **`next`** — `career_lab`, `externalId: null`.
- **`support`.** `{ level: support, areas: [safety, wellbeing], day: 2026-10-18, guidance }`. Raqam ham, savol ham yo'q.
- **`progress`.** Kategoriyalarda `previous` va `delta` bor (nuqta kamida 2 javobdan tuziladi). Qiziqishlarda S `delta: 100`.
