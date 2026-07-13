# Bug tuzatish hisoboti — 2026-07-13

Butun loyiha (backend, admin-web, parent, child) chuqur tekshirildi. Statik
tekshiruvlar (backend `tsc`, admin `tsc`, ikkala Flutter ilova `flutter analyze`)
**hammasi toza** edi — kompilyatsiya/analiz xatosi yo'q. Quyidagilar statik analiz
ushlay olmaydigan **runtime/logika** bug'lari: aniqlangan, tekshirilgan va
tuzatilgan.

---

## ✅ Tuzatilgan (kod o'zgartirildi)

### Backend (NestJS)
1. **Telegram login — ban chetlab o'tish** (`auth.service.ts` `telegramLogin`)
   Bloklangan (`isActive=false`) foydalanuvchi `/auth/telegram` orqali qayta token
   olib, ban'ni chetlab o'ta olardi. Endi `isActive` tekshiriladi + umumiy
   `buildAuthResponse` yo'liga o'tkazildi.
2. **Telegram login — 2-qurilma limitini chetlab o'tish** (yuqoridagi bilan birga)
   `telegramLogin` `createSession`'ni to'g'ridan chaqirib, `enforceParentDeviceLimit`'ni
   o'tkazib yuborardi. Endi `buildAuthResponse` orqali limit qo'llanadi.
3. **`createXpEvent` — bola o'zi cheksiz XP/don yasashi** (`gamification.controller.ts`)
   Endpoint'da rol cheklovi yo'q edi; bola o'z JWT'si bilan reyting XP va don
   (valyuta) yasay olardi. `@Roles('PARENT')` qo'shildi (tizim mukofotlari
   alohida server-side `awardXp` orqali beriladi).

### Admin-web (Next.js)
4. **Token refresh brauzerda umuman ishlamasdi** (`lib/api/client.ts`)
   Backend brauzerda refresh token'ni HttpOnly cookie'da beradi (body'da emas),
   shu sabab store'dagi `refreshToken` bo'sh bo'lib, `doRefresh()` `return null`
   qilardi → access token muddati tugashi bilan admin login'ga otvorardi. Endi
   bo'sh token'da ham cookie bilan refresh sinaladi.
5. **"Rejalashtirish" vaqtsiz — darhol hammaga yuborilardi** (`notification-composer.tsx`)
   Switch ON, lekin vaqt tanlanmasa `scheduledAt=undefined` bo'lib xabar DARHOL
   yuborilardi (toast esa "Rejalashtirildi" derdi). Endi vaqt majburiy +
   kelajakda bo'lishi tekshiriladi.
6. **Bloklashdan keyin ro'yxat yangilanmasdi** (`users/page.tsx`)
   `invalidateQueries(['users'])` yo'q edi → qator eski statusda qolib, qayta
   bosilganda takror bloklanardi. Invalidatsiya qo'shildi.
7. **`FileDropzone` object URL sizishi** (`file-dropzone.tsx`)
   Har render'da yangi `URL.createObjectURL` yaratilib revoke qilinmasdi. Endi
   `useEffect` bilan faqat `file` o'zgarganda yaratiladi va cleanup'da revoke.

### Parent ilova (Flutter)
8. **`Child.==`/`hashCode` `blockUninstall`'ni tashlab ketardi** (`child_model.dart`)
   Polling dedup (`listEquals`) o'zgarishni "bir xil" deb tashlab, "O'chirishni
   taqiqlash" holati eski ko'rinib qolardi. `==` va `hashCode`'ga qo'shildi.
9. **Sessiya tugatish — soxta muvaffaqiyat** (`active_sessions_screen.dart`)
   `onRevoke` await qilinmasdan darhol "tugatildi" toast'i chiqardi; so'rov xato
   bo'lsa ham. Endi await + try/catch, natijaga qarab toast.
10. **Location provider abadiy sizardi** (`child_place_provider.dart`,
    `child_location_provider.dart`) — keep-alive provider'lar autoDispose
    `childLocationProvider`'ni ushlab, uning 30s Timer + WS obunasi hech qachon
    to'xtamasdi (batareya/traffik). Ikkalasi `autoDispose` qilindi.
11. **`ChildLocation.fromBackendJson` himoyasiz cast** (`child_location.dart`)
    Bitta buzuq yozuv butun tarix/live ro'yxatini xato holatiga tushirardi. Endi
    hech qachon exception tashlamaydi (sibling modellar kabi).
12. **Round video chat'da imzolangan URL (telefonda ochilmasdi)** +
    **controller leak** (`chat_detail_screen.dart`) — signed `getFileUrl` o'rniga
    proxy `videoStreamUrl`; init xato bo'lganda controller dispose qilinadi.
13. **Voice chat `markAllRead(null)` BARCHA bolalarni "o'qilgan" qilardi**
    (`voice_chat_screen.dart`) — `childUserId` null bo'lsa bulk belgilash
    o'tkazib yuboriladi.
14. **Inline voice recorder nisbiy yo'l** (`chat_detail_screen.dart`) — native'da
    yozib bo'lmasdi; `getTemporaryDirectory()` bilan absolyut yo'l.

### Child ilova (Flutter)
15. **Socket.io reconnect'da handler'lar ko'payardi** (`socket_client.dart`) —
    har reconnect event handler'larni ustiga qo'shib, bitta emission N marta
    ishlardi. `socket.off(event)` qo'shildi.
16. **VideoPlayerController ikki marta dispose** (`classic_video_player_screen.dart`)
    — init await orasida ekran yopilsa double-dispose (debug assert). Ikki yo'l
    `_hasController` orqali muvofiqlashtirildi.
17. **SOS eski keshlangan joyni yuborardi** (`sos_provider.dart`) — age check
    yo'q edi; soatlab eski joy parent'ni noto'g'ri manzilga yuborishi mumkin edi.
    ≤2 daqiqa freshness guard + fresh fix, so'ng stale fallback.

---

## ⚠️ Tavsiya qilinadi, LEKIN qo'lda tuzatilmadi (sabab bilan)

Bular DB migratsiyasi, infratuzilma bilimi yoki ehtiyotkorlik talab qiladi —
ko'r-ko'rona o'zgartirish zarar keltirishi mumkin.

- **B4 — Gamification double-award (concurrency)**: `awardXp` (`findFirst`→`create`)
  va `awardStepDon`/`upsertSteps` idempotentligi atomik emas. Ikki bir vaqtdagi
  so'rov (retry) donni/XP'ni ikki marta bera oladi. **To'g'ri yechim**:
  `XpEvent`'ga `@@unique([childId, type, relatedId])` (migratsiya) + `create`'da
  P2002 catch; step uchun `ChildStepDaily` qatorini `SELECT ... FOR UPDATE` bilan
  qulflab, delta hisobi va balans yangilanishini bitta tranzaksiyada. **Nega
  hozir emas**: migratsiya DB ulanishini talab qiladi va mavjud dublikat qatorlar
  unique index yaratishda xato berishi mumkin — DB bilan sinash kerak.
- **B5 — Webhook IP allowlist `X-Forwarded-For` eng chap qiymatiga ishonadi**
  (`payments/guards/webhook-ip.guard.ts`): nginx `proxy_add_x_forwarded_for`
  bilan spoofing mumkin. **Nega hozir emas**: to'g'ri yechim nginx konfiguratsiyasiga
  bog'liq (trustProxy hop soni / eng o'ng qiymat) — noto'g'ri o'zgartirish
  qonuniy webhook'larni rad etishi mumkin. **Muhim**: bu faqat ikkilamchi himoya —
  asosiy himoya imzo (signature) tekshiruvi, u to'g'ri ishlaydi.
- **A5 — Video edit modal**: ochiq turганда ro'yxat refetch bo'lsa tahrir ustidan
  server qiymatlari yozilishi mumkin (`video-edit-modal.tsx`). Kichik oyna.
- **A6 — O'lik dropdown amallari**: bir nechta menyu elementida `onClick` yo'q
  (users "Ogohlantirish/Batafsil", olympiads, books, moderators). Kutilgan amal
  ishlamaydi — funksiya ulash yoki elementni olib tashlash kerak.
- **P9-P12 (parent voice/video, kichik)**: permission-await poyga (orphan yozuv),
  VoiceChatScreen round video 0:00 duration, `_stopAndReturn` re-entrancy guard,
  `_FullscreenVideoDialog` `catchError` yo'q.
- **P0 — Ba'zi repolar `parseListSafely` ishlatmaydi** (masalan
  `backend_routine_repository.dart`) — bitta buzuq element butun ro'yxatni
  yiqitishi mumkin.
- **C4 — Kontent to'liq ko'rish mukofotini oxirga "seek" qilib olish mumkin**
  (video/audio) — reward faqat `position>=duration` bilan aniqlanadi.
- **C5 — `OfflineBuffer.flush` flush davomida qo'shilgan elementni yo'qotishi
  mumkin** (poyga).
- **Eslatma — `RestrictionsSyncService`** jadval oynalarida qurilma-lokal
  `DateTime.now()` ishlatadi (qolgan ilova Toshkent UTC+5). Toshkentdagi qurilma
  uchun muammo emas; sayohatdagi/xato sozlangan qurilma oynalarni noto'g'ri
  hisoblashi mumkin — atayin qilinganini tasdiqlash kerak.
