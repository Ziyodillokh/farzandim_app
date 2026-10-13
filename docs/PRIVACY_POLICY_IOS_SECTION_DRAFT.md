# Maxfiylik siyosati — Parvoz Growth (iPhone) bo'limi (LOYIHA)

> **Kimga:** sayt egasi. Bu matnni `https://farzandimedu.uz/privacy.html` va
> `https://farzandimedu.uz/account-deletion.html` ga qo'shish uchun loyiha.
> Sayt fayllari (`website/public/*.html`) bu yerda O'ZGARTIRILMAGAN —
> matnni yuridik jihatdan siz tasdiqlaysiz va o'zingiz joylaysiz.
>
> **Asos:** 2026-10-13 holatidagi `feat/child-ios` kodi (bola ilovasi
> `farzandim_child/`, backend `backend/`). Har bir da'vo kod bilan
> tekshirilgan; manbalar §4 jadvalida. Audit topilmalari: F10, F15, F16,
> F20, F21, F52.
>
> **Joylashdan oldin tekshiring (kod hali o'zgarishi mumkin):**
> 1. Ilovada Sozlamalar → "Disconnect and delete my data" qatori bor va
>    backend bola uchun nimani o'chirishi (F15) shu matndagi tavsifga mos.
>    Mos kelmasa — "O'chirish" bandini haqiqiy xatti-harakatga moslang.
> 2. DON reytingida boshqa foydalanuvchilarga bolaning faqat ismi + familiya
>    bosh harfi ko'rinadi, rasmi ko'rinmaydi (F16, `ranking_name_privacy.dart`,
>    `ranking_avatar.dart`; backend `leaderboard.service.ts` `maskName`).
> 3. Support e-mail: matnda `support@farzandimedu.uz` (ilovadagi manzil).
>    Saytda hozir `farzandimtech@gmail.com` — bittasini tanlang (F44) va
>    hamma joyda bir xil qiling.
> 4. HealthKit iOS build'dan olib tashlangan (F5) — matn "Apple Health
>    ishlatilmaydi" deydi.
> 5. "Ekran vaqti o'chirilsa ota-onaga xabar boradi" — backend
>    `permission-alert.service.ts` (`screenTimePermission`) PROD'ga deploy
>    qilingandan keyingina to'g'ri (F24). Deploy'gacha shu jumlani
>    ("…va ota-onaga xabar boradi" / "and the parent is notified" /
>    "а родитель получает уведомление") olib tashlang.

---

## 1. `privacy.html` ga qo'shiladigan yangi bo'lim

Tavsiya etilgan joy: 2-bo'limdan ("Yig'iladigan ma'lumotlar") keyin, alohida
sarlavha va `id="ios"` bilan (App Store Connect'da
`https://farzandimedu.uz/privacy.html#ios` havolasini ham berish mumkin).
Uchala til bir sahifada (yoki `?lang=` bilan) — App Review EN/RU matnni
o'qiy olishi kerak.

### 1.1 UZ

```text
2.3. Parvoz Growth — iPhone (iOS) ilovasi

Parvoz Growth'ni ota-ona bolaning iPhone'iga o'rnatadi va 5 xonali oila kodi bilan Parvoz Parents ilovasiga ulaydi. Ilovadan foydalanishdan oldin ota-ona rozilik ekranini tasdiqlaydi.

iPhone ilovasi serverlarimizga yuboradigan ma'lumotlar:
• Joylashuv — koordinatalar, aniqlik, tezlik, yo'nalish, balandlik va vaqt. Joylashuv ruxsati "Har doim" bo'lsa, ilova yopiq bo'lganda ham yuboriladi. Maqsad: ota-onaning xaritasi, harakat tarixi, saqlangan joylarga kelish/ketish xabarlari (serverda hisoblanadi) va SOS.
• SOS signali — joriy joylashuv bilan, faqat bog'langan ota-onaga. Favqulodda xizmatlarga yuborilmaydi.
• Oila xabarlari — matn, ovozli va video xabarlar, rasmlar va fayllar; faqat bola va uning ota-onasi o'rtasida.
• Profil — ism, yosh yoki tug'ilgan sana, jins, viloyat, ixtiyoriy profil rasmi, qiziqishlar.
• Qadamlar — kunlik qadamlar soni, iPhone harakat sensoridan (Core Motion). Apple Salomatlik (HealthKit) ma'lumotlari o'qilmaydi va yozilmaydi.
• Qurilma holati — batareya darajasi va zaryadlanish, qurilma modeli, iOS va ilova versiyasi, ruxsatlar holati (joylashuv, bildirishnomalar), Ekran vaqti himoyasi yoqilganmi va nechta ilova/toifa/sayt tanlangani (faqat SONI).
• O'quv faolligi — ko'rilgan va sevimli videolar, audiokitob progressi, o'qilgan kitob va maqolalar, test va olimpiada javoblari va natijalari, DON ballari va ketma-ket kunlar (streak).
• Qo'shimcha vaqt so'rovi — daqiqalar soni va ixtiyoriy sabab matni (ilova nomisiz).
• Texnik identifikatorlar — bola akkaunti ID'si va push-bildirishnoma tokeni.

iPhone'da YIG'ILMAYDI va serverga YUBORILMAYDI:
• o'rnatilgan ilovalar ro'yxati, qaysi ilovalar cheklangani, ilovalardan foydalanish vaqti va statistikasi;
• brauzer tarixi, Wi-Fi tarmoq nomi, kontaktlar, Apple Salomatlik ma'lumotlari;
• reklama identifikatori (IDFA). Ilovada reklama va kuzatuv (tracking) yo'q.

Ekran vaqti (Apple Family Controls): ota-ona himoyani bolaning iPhone'ida Face ID yoki parol bilan yoqadi (ixtiyoriy: Apple Family Sharing orqali qat'iy rejim). Cheklanadigan ilovalarni ota-ona Apple'ning tizim oynasida tanlaydi; bu tanlov faqat qurilmada saqlanadi. Serverdan faqat ilova nomisiz qoidalar keladi (hozir bloklash, vaqt oralig'i, bitta kunlik limit, tasdiqlangan qo'shimcha vaqt). Himoya yoqilganda sana va vaqt "Avtomatik" holatda turadi; ota-ona "O'chirishni taqiqlash"ni yoqsa, iPhone'da ilovalarni o'chirish bloklanadi. Himoya iPhone Sozlamalari → Ekran vaqti orqali o'chirilsa, bular ham to'xtaydi va ota-onaga xabar boradi.

Kim ko'radi: bolaning ma'lumotlarini faqat bog'langan ota-ona(lar) ko'radi. DON reytingida boshqa Parvoz foydalanuvchilari faqat bolaning ismi va familiyasining bosh harfini (masalan, "Akmal T."), viloyati va DON ballini ko'radi; rasm ko'rsatilmaydi.

Uchinchi tomon xizmatlari (iPhone ilovasi):
• Google Firebase (Google LLC) — push-bildirishnomalar (Cloud Messaging), nosozlik hisobotlari (Crashlytics: qurilma modeli, iOS versiyasi, xato tafsilotlari; bola ismi bilan bog'lanmaydi), anonim texnik identifikator (Authentication) va DON/streak hisoblagichlari (Cloud Firestore). Parvoz Growth'da Firebase Analytics va App Check ishlatilmaydi.
• Apple — push-bildirishnomalarni yetkazish (APNs) va Ekran vaqti (faqat qurilmada).
• YouTube (Google) — ta'limiy videolar YouTube'ning maxfiylik rejimidagi (youtube-nocookie.com) o'rnatilgan pleyerida ochiladi; ijro Google siyosatiga muvofiq qayta ishlanadi.
Boshqa barcha ma'lumotlar o'z serverlarimizda (PostgreSQL, MinIO) saqlanadi va sotilmaydi.

Saqlash muddati: joylashuv tarixi (nuqtalar va to'xtash joylari) 90 kundan keyin avtomatik o'chiriladi. Xabarlar, media, qadamlar va o'quv faolligi bola akkaunti mavjud ekan saqlanadi va quyidagi yo'llar bilan o'chiriladi. Nosozlik hisobotlari Firebase Crashlytics saqlash muddatiga ko'ra o'chiriladi.

O'chirish: iPhone'da Parvoz Growth → Profil → ⚙ → "Disconnect and delete my data" (o'zbekcha interfeysda tegishli tarjima). Bu iPhone'ni oiladan uzadi, bola akkauntini va u yaratgan ma'lumotlarni serverlarimizdan o'chiradi hamda qurilmadagi Ekran vaqti cheklovlarini olib tashlaydi. Ota-ona yaratgan bola profili Parvoz Parents'da ota-ona uni yoki o'z akkauntini o'chirmaguncha qoladi. Shuningdek, support@farzandimedu.uz manziliga yozish mumkin.
```

### 1.2 EN

```text
2.3. Parvoz Growth — iPhone (iOS) app

A parent installs Parvoz Growth on their child's iPhone and links it to the Parvoz Parents app with a 5-digit family code. Before the app is used, the parent confirms the consent screen.

Data the iPhone app sends to our servers:
• Location — coordinates, accuracy, speed, heading, altitude and time. If location access is set to "Always", it is also sent while the app is closed. Purpose: the parents' map, location history, arrival/departure alerts for saved places (calculated on our server) and SOS.
• SOS alerts — with the current location, only to the linked parents. They are not sent to emergency services.
• Family messages — text, voice and video messages, photos and files, only between the child and their parents.
• Profile — name, age or date of birth, gender, region, an optional profile photo and interests.
• Steps — daily step counts from the iPhone motion sensor (Core Motion). Apple Health (HealthKit) data is neither read nor written.
• Device status — battery level and charging state, device model, iOS and app version, permission states (location, notifications), whether Screen Time protection is on, and how many apps, categories and websites are selected (counts only).
• Learning activity — watched and favourite videos, audiobook progress, books and articles read, quiz and olympiad answers and results, DON points and streaks.
• Extra-time requests — the number of minutes and an optional reason (no app name).
• Technical identifiers — the child account ID and the push notification token.

Not collected on the iPhone and never sent to our servers:
• the list of installed apps, which apps are restricted, and app usage time or statistics;
• browsing history, Wi-Fi network name, contacts, Apple Health data;
• the advertising identifier (IDFA). The app has no ads and no tracking.

Screen Time (Apple Family Controls): a parent turns on protection on the child's iPhone with Face ID or the passcode (optionally, a strict mode through Apple Family Sharing). The parent picks the apps to restrict in Apple's system picker; that selection is stored only on the device. Our server sends only rules without app names (block now, time windows, one daily limit, approved extra time). While protection is on, Date & Time stays on Automatic; if the parent turns on "Prevent uninstall", deleting apps on the iPhone is blocked. If protection is turned off in iPhone Settings › Screen Time, these stop and the parent is notified.

Who can see it: the child's data is visible only to the linked parent(s). In the DON ranking, other Parvoz users see only the child's first name and surname initial (for example, "Akmal T."), region and DON points; no photo is shown.

Third-party services (iPhone app):
• Google Firebase (Google LLC) — push notifications (Cloud Messaging), crash reports (Crashlytics: device model, iOS version, error details; not linked to the child's name), an anonymous technical identifier (Authentication) and DON/streak counters (Cloud Firestore). Firebase Analytics and App Check are not used in Parvoz Growth.
• Apple — push notification delivery (APNs) and Screen Time (on the device only).
• YouTube (Google) — educational videos play in YouTube's privacy-enhanced embedded player (youtube-nocookie.com); playback is processed under Google's policies.
All other data is stored on our own servers (PostgreSQL, MinIO) and is never sold.

Retention: location history (points and stops) is deleted automatically after 90 days. Messages, media, steps and learning activity are kept while the child account exists and are deleted as described below. Crash reports are deleted according to Firebase Crashlytics retention.

Deletion: on the iPhone open Parvoz Growth → Profile → ⚙ → "Disconnect and delete my data". This disconnects the iPhone from the family, deletes the child account and the data it created from our servers and removes the Screen Time restrictions on the device. The child profile created by the parent stays in Parvoz Parents until the parent deletes it or their own account. You can also e-mail support@farzandimedu.uz.
```

### 1.3 RU

```text
2.3. Parvoz Growth — приложение для iPhone (iOS)

Родитель устанавливает Parvoz Growth на iPhone ребёнка и связывает его с приложением Parvoz Parents по 5-значному семейному коду. Перед началом использования родитель подтверждает экран согласия.

Данные, которые приложение для iPhone отправляет на наши серверы:
• Геолокация — координаты, точность, скорость, направление, высота и время. Если доступ к геопозиции установлен на «Всегда», данные отправляются и когда приложение закрыто. Цель: карта родителей, история перемещений, уведомления о приходе в сохранённые места и уходе из них (рассчитываются на сервере) и SOS.
• SOS-сигнал — с текущим местоположением, только связанным родителям. В экстренные службы не отправляется.
• Семейные сообщения — текстовые, голосовые и видеосообщения, фото и файлы только между ребёнком и его родителями.
• Профиль — имя, возраст или дата рождения, пол, регион, необязательное фото профиля и интересы.
• Шаги — количество шагов за день с датчика движения iPhone (Core Motion). Данные Apple Здоровье (HealthKit) не читаются и не записываются.
• Состояние устройства — уровень заряда и зарядка, модель устройства, версии iOS и приложения, состояние разрешений (геолокация, уведомления), включена ли защита Экранного времени и сколько приложений, категорий и сайтов выбрано (только количество).
• Учебная активность — просмотренные и избранные видео, прогресс аудиокниг, прочитанные книги и статьи, ответы и результаты тестов и олимпиад, баллы DON и серии дней.
• Запросы дополнительного времени — количество минут и необязательная причина (без названия приложения).
• Технические идентификаторы — ID аккаунта ребёнка и токен push-уведомлений.

На iPhone НЕ собирается и не отправляется на наши серверы:
• список установленных приложений, какие приложения ограничены, время и статистика использования приложений;
• история браузера, имя сети Wi-Fi, контакты, данные Apple Здоровье;
• рекламный идентификатор (IDFA). В приложении нет рекламы и отслеживания.

Экранное время (Apple Family Controls): родитель включает защиту на iPhone ребёнка с помощью Face ID или код-пароля (дополнительно — строгий режим через Семейный доступ Apple). Ограничиваемые приложения родитель выбирает в системном окне Apple; этот выбор хранится только на устройстве. С сервера приходят только правила без названий приложений (заблокировать сейчас, интервалы времени, один дневной лимит, одобренное дополнительное время). Пока защита включена, дата и время остаются в режиме «Автоматически»; если родитель включил «Запрет удаления», удаление приложений на iPhone блокируется. Если защиту отключить в Настройках iPhone › Экранное время, эти ограничения снимаются, а родитель получает уведомление.

Кто видит данные: данные ребёнка видят только связанные родители. В рейтинге DON другие пользователи Parvoz видят только имя ребёнка и первую букву фамилии (например, «Akmal T.»), регион и баллы DON; фото не показывается.

Сторонние сервисы (приложение для iPhone):
• Google Firebase (Google LLC) — push-уведомления (Cloud Messaging), отчёты о сбоях (Crashlytics: модель устройства, версия iOS, сведения об ошибке; не связываются с именем ребёнка), анонимный технический идентификатор (Authentication) и счётчики DON/серий (Cloud Firestore). Firebase Analytics и App Check в Parvoz Growth не используются.
• Apple — доставка push-уведомлений (APNs) и Экранное время (только на устройстве).
• YouTube (Google) — обучающие видео воспроизводятся во встроенном плеере YouTube в режиме повышенной конфиденциальности (youtube-nocookie.com); воспроизведение обрабатывается по правилам Google.
Все остальные данные хранятся на наших собственных серверах (PostgreSQL, MinIO) и никогда не продаются.

Срок хранения: история геолокации (точки и остановки) автоматически удаляется через 90 дней. Сообщения, медиафайлы, шаги и учебная активность хранятся, пока существует аккаунт ребёнка, и удаляются способами, описанными ниже. Отчёты о сбоях удаляются в соответствии со сроками хранения Firebase Crashlytics.

Удаление: на iPhone откройте Parvoz Growth → Профиль → ⚙ → «Отключиться и удалить мои данные». Это отключает iPhone от семьи, удаляет аккаунт ребёнка и созданные им данные с наших серверов и снимает ограничения Экранного времени на устройстве. Профиль ребёнка, созданный родителем, остаётся в Parvoz Parents, пока родитель не удалит его или свой аккаунт. Также можно написать на support@farzandimedu.uz.
```

---

## 2. `account-deletion.html` ga qo'shiladigan bo'lim

Hozirgi sahifa faqat ota-ona ilovasini tasvirlaydi ("Hisobni butunlay
o'chirish"). Quyidagini "1-usul"dan keyin alohida bo'lim sifatida qo'shing.

**UZ**

```text
Bolaning iPhone'idagi Parvoz Growth ilovasi
1. Parvoz Growth'ni oching → pastdagi "Profil" bo'limi → yuqoridagi ⚙ (Sozlamalar).
2. "Disconnect and delete my data" qatorini tanlang (o'zbekcha interfeysda tegishli tarjima) va tasdiqlang.
3. iPhone oiladan uziladi, bola akkaunti va u yaratgan ma'lumotlar (xabarlar, ovozli va video xabarlar, rasmlar, joylashuv tarixi, qadamlar, o'quv faolligi) serverlarimizdan o'chiriladi, qurilmadagi Ekran vaqti cheklovlari olib tashlanadi.
Ota-ona yaratgan bola profili Parvoz Parents'da qoladi — uni ota-ona ilovasida o'chirish mumkin. Ilovaga kira olmasangiz: support@farzandimedu.uz (mavzu: "Akkauntni o'chirish", bola ismi va ota-ona telefon raqami).
```

**EN**

```text
Parvoz Growth on the child's iPhone
1. Open Parvoz Growth → "Profile" tab → ⚙ (Settings) at the top.
2. Tap "Disconnect and delete my data" and confirm.
3. The iPhone is disconnected from the family, the child account and the data it created (messages, voice and video messages, photos, location history, steps, learning activity) are deleted from our servers, and the Screen Time restrictions on the device are removed.
The child profile created by the parent stays in Parvoz Parents and can be deleted there. If you cannot open the app, e-mail support@farzandimedu.uz (subject "Account deletion", with the child's name and the parent's phone number).
```

**RU**

```text
Parvoz Growth на iPhone ребёнка
1. Откройте Parvoz Growth → вкладка «Профиль» → ⚙ (Настройки) вверху.
2. Выберите «Отключиться и удалить мои данные» и подтвердите.
3. iPhone отключается от семьи, аккаунт ребёнка и созданные им данные (сообщения, голосовые и видеосообщения, фото, история геолокации, шаги, учебная активность) удаляются с наших серверов, а ограничения Экранного времени на устройстве снимаются.
Профиль ребёнка, созданный родителем, остаётся в Parvoz Parents, и его можно удалить там. Если не удаётся открыть приложение, напишите на support@farzandimedu.uz (тема «Удаление аккаунта», имя ребёнка и номер телефона родителя).
```

> ⚠️ 3-banddagi ro'yxat F15 backend o'zgarishi bilan aynan mos bo'lishi
> kerak (bola `DELETE /users/me` chaqirganda nima o'chadi). Joriy
> `users.service.ts` `deleteAccount` bola foydalanuvchisini o'chiradi
> (bog'liq yozuvlar cascade bilan); joylashuv tarixi va qadamlar ota-ona
> egalik qiladigan `Child` profiliga bog'langan bo'lishi mumkin — deploy
> qilingan kodda tekshirib, ro'yxatni moslang.

---

## 3. Mavjud `privacy.html` matniga tuzatishlar (UZ, egasi uchun)

| Joy (2026-08-07 versiyasi) | Muammo | Tuzatish |
|---|---|---|
| 2-bo'lim B), "ACCESS_BACKGROUND_LOCATION" | Android atamasi | "(Android: ACCESS_BACKGROUND_LOCATION; iPhone: joylashuv ruxsati "Har doim")" |
| 2-bo'lim B), "Wi-Fi tarmoq nomi" | 2026-08-17 dan beri hech bir ilova yig'maydi (`device_info_service.dart`) | Qatorni o'chiring |
| 2-bo'lim B), "Foydalanilgan ilovalar, kategoriyalari va vaqtlari" | Faqat Android; iPhone'da yig'ilmaydi | "(faqat Android ilovasi; iPhone'da yig'ilmaydi — 2.3-bo'limga qarang)" |
| 2-bo'lim B), "90 kun" ovoz/video | `retention.service.ts` faqat `locations`, `location_stops`, `app_usage` ni 90 kunda o'chiradi | Haqiqiy muddatni yozing: "xabarlar va media akkaunt o'chirilguncha saqlanadi" yoki 90 kunlik o'chirishni kodda qo'shing |
| 2.1 Health Connect | Faqat Android | Sarlavhaga "(Android)" qo'shing; iPhone uchun 2.3-bo'limga havola |
| 2.2 Device Admin | Faqat Android | Sarlavhaga "(Android)" qo'shing; iPhone'dagi "O'chirishni taqiqlash" 2.3-bo'limda |
| 4-bo'lim, "Firebase Auth emas" | Bola ilovasi Firebase anonim autentifikatsiyasidan foydalanadi (`pairing_provider.dart`) | "Asosiy autentifikatsiya — o'z JWT tizimimiz; bola ilovasi qo'shimcha ravishda Firebase'ning anonim texnik identifikatoridan foydalanadi" |
| 4-bo'lim, Firebase qatori | Analytics va App Check faqat ota-ona ilovasida; bola ilovasi Firestore'dan DON/streak uchun foydalanadi | "Firebase: push (FCM), Crashlytics; ota-ona ilovasida — Analytics va App Check; bola ilovasida — anonim Auth ID va Firestore (DON/streak hisoblagichlari)" |
| 4-bo'lim | YouTube yo'q | "YouTube (youtube-nocookie.com o'rnatilgan pleyer) — ta'limiy videolar" qo'shing |
| 4-bo'lim, "To'lov provayderi" | iPhone'da faqat Apple IAP (F52) | "iPhone/iPad'da Parvoz Parents obunasi faqat Apple In-App Purchase orqali; Click/Uzum/Payme — Android va veb" |
| 5-bo'lim, "ilova-foydalanish ma'lumotlari" | iPhone'da yo'q | "(Android)" qo'shing |
| 6-bo'lim | DON reytingi tilga olinmagan (F16) | "DON reytingida boshqa foydalanuvchilarga faqat ism, familiya bosh harfi, viloyat va DON balli ko'rinadi" |
| 7-bo'lim, "O'chirish" | Faqat ota-ona yo'li | Bola ilovasi yo'lini qo'shing (§2 dagi matn) |
| Sarlavha | "So'nggi yangilanish: 2026-08-07" | Joylash sanasiga yangilang |
| Butun sahifa | Faqat o'zbekcha | Kamida 2.3-bo'lim va asosiy bandlarning EN/RU qisqacha nusxasi (App Review EN/RU o'qiydi) |

---

## 4. Manbalar (kod tekshiruvi, 2026-10-13)

| Da'vo | Manba |
|---|---|
| Joylashuv yuboriladigan maydonlar, fonda "Always" bilan | `farzandim_child/lib/features/location/data/services/location_service.dart` (`POST /location`, `AppleSettings(allowBackgroundLocationUpdates: true)`) |
| Geo-zona xabarlari serverda | `backend/src/modules/geo-zones/`, `location.service.ts` |
| SOS joylashuv bilan | `lib/features/sos/data/repositories/backend_sos_repository.dart` |
| Qurilma holati, Wi-Fi yo'q | `lib/features/device_info/data/services/device_info_service.dart` |
| Ekran vaqti: faqat son va holat | `lib/features/screen_time/data/ios_restrictions_sync_service.dart` (`selectionAppName`), `lib/core/platform/platform_capabilities.dart` (`canUploadAppUsage => isAndroid`) |
| Sana/vaqt avtomatik, denyAppRemoval | `ios/Shared/ParvozShield.swift` `applyExtras` |
| Standart `.individual`, ixtiyoriy `.child` | `ios/Runner/ScreenTimePlugin.swift` (`mode == "child" ? .child : .individual`) |
| Profil maydonlari | `lib/features/account/data/repositories/child_repository.dart`, `lib/features/onboarding/data/interests_sync_service.dart` |
| Firebase: anonim Auth, Firestore, FCM, Crashlytics; Analytics/App Check yo'q | `farzandim_child/pubspec.yaml`, `pairing_provider.dart`, `xp_service.dart`, `main.dart`, `ios/Runner/GoogleService-Info.plist` |
| YouTube nocookie | `backend/src/modules/consumer-content/consumer-content.controller.ts` |
| 90 kunlik saqlash | `backend/src/modules/retention/retention.service.ts` |
| Reyting: ism niqobi, rasmsiz | `lib/features/ranking/data/ranking_name_privacy.dart`, `lib/features/ranking/presentation/widgets/ranking_avatar.dart`, `backend/src/modules/leaderboard/leaderboard.service.ts` |
| Ajratish Ekran vaqtini tiklaydi | `lib/features/pairing/presentation/providers/pairing_provider.dart` (`unpair` → `screenTimeChannel.reset()`) |
