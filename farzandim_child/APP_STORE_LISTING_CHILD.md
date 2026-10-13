# Parvoz Growth (iOS, `uz.parvoz.growth`) — App Store Connect matnlari

> Bu fayl BOLA ilovasining **iOS** versiyasi uchun App Store'da ko'rinadigan
> matnlar (nom, subtitle, promo, tavsif, kalit so'zlar, skrinshotlar).
> App Review Notes, Age Rating, App Privacy, Export Compliance va egasi
> qo'lda bajaradigan ishlar ro'yxati: `docs/APP_STORE_SUBMISSION_CHILD_IOS.md`.
> Maxfiylik siyosatiga iOS bo'limi loyihasi: `docs/PRIVACY_POLICY_IOS_SECTION_DRAFT.md`.
> Android ro'yxati: `PLAY_STORE_LISTING_CHILD.md`.
>
> **Matnlar joriy kodga mos (2026-10-13, `feat/child-ios`). O'zgartirishdan
> oldin quyidagi qoidalarni o'qing:**
> - **Kids Category EMAS.** Shuning uchun nom, subtitle, promo, tavsif,
>   skrinshot yozuvlari va ikonada "for kids", "for children", "для детей",
>   "детское приложение" kabi so'zlar ISHLATILMAYDI (Guideline 2.3.8, 5.1.4).
>   Matnlar OTA-ONA ovozida yozilgan: ilovani ota-ona bolaning iPhone'iga
>   o'rnatadi va o'z ilovasiga ulaydi. Kalit so'zlarda `kids` yo'q.
> - **Android / Google Play tilga olinmaydi** (Guideline 2.3.10). Ota-ona
>   ilovasi faqat nomi bilan — **Parvoz Parents** — aytiladi.
> - **Ekran vaqti:** standart rejim — ota-ona bolaning iPhone'ida Face ID
>   yoki parol bilan tasdiqlaydi (`.individual`). Apple Family Sharing
>   ishlatadigan oilalar uchun ixtiyoriy "Strict protection" (`.child`).
>   Family Sharing SHART EMAS — matnlarda shart deb yozmang.
> - iOS'da ilovalar ro'yxati va ilovalardan foydalanish statistikasi
>   **qurilmadan chiqmaydi**. Ota-ona ilovasida iPhone ilovalari bitta
>   "iPhone: tanlangan ilovalar" (EN "iPhone: selected apps") elementi bo'lib
>   ko'rinadi — faqat himoya yoqilganmi va nechta ilova/toifa/sayt tanlangani.
> - Parvoz Growth'da **xarid yo'q**. Ba'zi imkoniyatlar ota-onaning Parvoz
>   tarifiga bog'liq (narx va to'lov usuli tilga olinmaydi).
> - SOS — "bir bosish" EMAS: Chats → "SOS message" → slayderni surish.
>   Favqulodda xizmatlarga qo'ng'iroq qilmaydi.
> - Qadamlar — iPhone harakat sensori (Core Motion). Apple Health ishlatilmaydi.
>
> **Til:** App Store Connect'da o'zbek tili yo'q — asosiy til **English (U.S.)**,
> qo'shimcha **Russian**. Ilovaning o'zi uz/ru/en tillarida ishlaydi.
>
> **Uzunlik tekshiruvi** (2026-10-13, python bilan sanalgan): subtitle EN 27 /
> RU 27 belgi (limit 30 belgi); promo EN 163 / RU 159 belgi (limit 170);
> tavsif EN va RU 4 000 belgidan kam; kalit so'zlar EN 95 bayt / RU 94 bayt
> (limit 100 — kirill harfi 2 bayt, shuning uchun BAYT sanaladi). Matnni
> o'zgartirsangiz qayta sanang:
> `python3 -c "s='...'; print(len(s), len(s.encode('utf-8')))"`

---

## 1. App Information

| Maydon | Qiymat |
|---|---|
| Name (≤30) | `Parvoz Growth` |
| Subtitle EN (≤30) | `Family location, SOS & chat` |
| Subtitle RU (≤30) | `Семейная безопасность и SOS` |
| Bundle ID | `uz.parvoz.growth` |
| SKU | `parvoz-growth-ios` (istalgan noyob qiymat) |
| Primary category | Lifestyle |
| Secondary category | Education |
| Kids Category / "Made for Kids" | **Tanlamang.** Bu ota-ona nazorati tizimining ilovasi; asosiy auditoriya — ota-onalar. |
| Content rights | **Yes** — ilova uchinchi tomon kontentini ko'rsatadi (YouTube videolar, audiokitoblar, kitoblar). Huquqlaringiz borligini tasdiqlang. |
| Copyright | `2026 FARZANDIM TECH MCHJ` |

**URL'lar**
- Privacy Policy: `https://farzandimedu.uz/privacy.html` — topshirishdan
  OLDIN unga iOS bo'limini qo'shing (`docs/PRIVACY_POLICY_IOS_SECTION_DRAFT.md`).
- Support URL: `https://farzandimedu.uz`
- Marketing URL: `https://farzandimedu.uz`

---

## 2. Promotional Text (≤170)

**EN**

```text
Companion to the Parvoz Parents app: family location sharing, SOS alerts, voice and video messages, Screen Time limits and learning content on your child's iPhone.
```
**RU**

```text
Компаньон приложения Parvoz Parents: геолокация для семьи, SOS-сигналы, голосовые и видеосообщения, ограничения Экранного времени и обучение на iPhone ребёнка.
```

---

## 3. Description (≤4000)

### EN

```text
Parvoz Growth is the companion app for the Parvoz family safety service. A parent installs it on their child's iPhone and links it to the Parvoz Parents app with a 5-digit family code. Parvoz Growth does not work on its own.

WHAT THE APP DOES
• Location — shares the iPhone's location with the linked parents, also in the background when location access is set to "Always", so they can see it on the map and get alerts when the child arrives at or leaves places they saved.
• SOS — slide to confirm and the app sends an alert with the current location to the linked parents. It does not contact emergency services.
• Family messages — text, voice and video messages and photos, only between the child and their own parents.
• Steps — counts daily steps with the iPhone motion sensor and shows them to the parents. Apple Health is not used.
• Screen Time — a parent turns on protection on the child's iPhone and confirms with Face ID or the passcode. Families who use Apple Family Sharing can choose the optional strict mode instead. The parent then picks the apps to restrict in Apple's app picker, protected by a parent PIN. From Parvoz Parents they can block the chosen apps now, set one daily limit for them, or schedule restriction times. Saved schedules and limits are enforced by iOS even when Parvoz Growth is closed. On the restriction screen the child can ask for more time, and the parent approves or declines.
• Learning — audiobooks with background playback, educational videos, books, quizzes and olympiads. Correct answers and daily activity earn DON points — virtual in-app points with no cash value.

PRIVACY AND TRANSPARENCY
• Which apps are restricted, the list of apps and app usage stay on the iPhone. Parvoz only learns whether protection is on and how many apps are selected.
• The app is not hidden: it has its own icon and name. Location and other access can be reviewed or turned off at any time in iPhone Settings.
• Every permission is explained before iOS asks for it, and the app keeps working if a permission is declined.
• While protection is on, Date & Time stays on Automatic so limits can't be bypassed by changing the clock. If the parent turns on "Prevent uninstall", deleting apps on the iPhone is blocked. Both end when protection is turned off in iPhone Settings › Screen Time.
• For parents supervising their own child with the child's knowledge — not for monitoring other people.
• No ads. Data is never sold or used for advertising.
• Disconnect and delete the child's data at any time in Settings › "Disconnect and delete my data".

REQUIREMENTS
• The Parvoz Parents app on the parent's phone, and an internet connection.
• For Screen Time: an iPhone with a passcode, signed in to an Apple Account.
• Parvoz Growth has no in-app purchases. Some features — location alerts and history, app limits and schedules, part of the learning library — depend on the parent's Parvoz plan.

Privacy policy: https://farzandimedu.uz/privacy.html
Support: support@farzandimedu.uz
```

### RU

```text
Parvoz Growth — приложение-компаньон семейной системы безопасности Parvoz. Родитель устанавливает его на iPhone ребёнка и связывает с приложением Parvoz Parents по 5-значному семейному коду. Отдельно Parvoz Growth не работает.

ЧТО ДЕЛАЕТ ПРИЛОЖЕНИЕ
• Геолокация — передаёт местоположение iPhone связанным родителям, в том числе в фоне, если доступ к геопозиции установлен на «Всегда», чтобы они видели его на карте и получали уведомления, когда ребёнок приходит в сохранённые ими места или уходит из них.
• SOS — после подтверждения сдвигом приложение отправляет связанным родителям сигнал с текущим местоположением. Экстренные службы не вызываются.
• Семейные сообщения — текстовые, голосовые и видеосообщения и фото только между ребёнком и его родителями.
• Шаги — считает шаги за день с помощью датчика движения iPhone и показывает их родителям. Apple Здоровье не используется.
• Экранное время — родитель включает защиту на iPhone ребёнка и подтверждает Face ID или код-паролем. Семьи, которые пользуются Семейным доступом Apple, могут выбрать дополнительный строгий режим. Затем родитель выбирает ограничиваемые приложения в системном окне выбора Apple, защищённом PIN-кодом родителя. В Parvoz Parents можно сразу заблокировать выбранные приложения, задать для них один дневной лимит или расписание ограничений. Сохранённые расписания и лимиты iOS соблюдает, даже когда Parvoz Growth закрыт. На экране ограничения ребёнок может попросить больше времени, а родитель одобряет или отклоняет запрос.
• Обучение — аудиокниги с фоновым воспроизведением, обучающие видео, книги, тесты и олимпиады. За правильные ответы и активность начисляются баллы DON — виртуальные баллы внутри приложения без денежной стоимости.

КОНФИДЕНЦИАЛЬНОСТЬ И ОТКРЫТОСТЬ
• Какие приложения ограничены, список приложений и их использование остаются на iPhone. Parvoz знает только, включена ли защита и сколько приложений выбрано.
• Приложение не скрыто: у него своя иконка и название. Доступ к геопозиции и другим данным можно проверить или отключить в Настройках iPhone.
• Каждое разрешение объясняется до запроса iOS, и приложение продолжает работать, если разрешение отклонено.
• Пока защита включена, дата и время остаются в режиме «Автоматически», чтобы лимиты нельзя было обойти переводом часов. Если родитель включил «Запрет удаления», удаление приложений на iPhone блокируется. Оба ограничения снимаются, когда защита отключена в Настройках iPhone › Экранное время.
• Для родителей, которые заботятся о своём ребёнке с его ведома, — не для наблюдения за другими людьми.
• Без рекламы. Данные не продаются и не используются для рекламы.
• Отключиться и удалить данные ребёнка можно в любой момент: Настройки › «Отключиться и удалить мои данные».

ТРЕБОВАНИЯ
• Приложение Parvoz Parents на телефоне родителя и подключение к интернету.
• Для Экранного времени: iPhone с код-паролем и выполненным входом в Apple Account.
• В Parvoz Growth нет встроенных покупок. Часть функций — уведомления и история геолокации, лимиты и расписания приложений, часть обучающей библиотеки — зависит от тарифа Parvoz у родителя.

Политика конфиденциальности: https://farzandimedu.uz/privacy.html
Поддержка: support@farzandimedu.uz
```

> Tavsifdagi Settings qatori nomi ilovadagi qator bilan BIR XIL bo'lishi
> shart: EN `Disconnect and delete my data`, RU `Отключиться и удалить мои данные`.
> Ilovada boshqacha tarjima qilingan bo'lsa (`assets/translations/*.json`),
> shu yerni ilovaga moslang. "Prevent uninstall" — Parvoz Parents'dagi
> sozlama nomi; ota-ona ilovasidagi nom o'zgarsa, bu yerni ham yangilang.
> Support e-mail ilovadagi (`settings_screen.dart`) manzil bilan bir xil;
> sayt boshqa manzil ishlatadi — `docs/APP_STORE_SUBMISSION_CHILD_IOS.md`
> §8 (F44) ga qarang.

---

## 4. Keywords (≤100 BAYT, vergul bilan, bo'sh joysiz)

- EN (95 bayt): `parental control,family locator,gps tracker,location,sos,screen time,geofence,safety,steps,chat`
- RU (94 bayt): `родительский контроль,геолокация,семья,sos,gps,трекер`

`kids`, `child`, `дети`, `детский` ATAYLAB yo'q (Kids Category atamalari).
Nom va subtitle'dagi so'zlarni (`Parvoz`, `Growth`) takrorlash shart emas —
Apple ularni allaqachon indekslaydi.

---

## 5. Skrinshotlar

- Majburiy: **6.9" iPhone** — 1320 × 2868 (yoki 1290 × 2796) px, 3–10 ta.
  iPad skrinshoti kerak emas (ilova faqat iPhone uchun, `UIDeviceFamily = 1`).
- Faqat **topshiriladigan iOS build'dan** oling. Tavsiya etilgan ekranlar:
  1) Bosh sahifa, 2) Chats → SOS dialogi, 3) Oila chati / video xabar,
  4) Audiokitoblar, 5) Statistika (qadamlar), 6) Ekran vaqti ("Turn on
  protection" + "Restricted apps"), 7) Ruxsatlar ekrani.
- Skrinshot yozuvlarida "for kids / для детей / детское" ISHLATMANG; ota-ona
  ovozida yozing (masalan: "Know they arrived safely", "SOS with location").
- Skrinshotlarda **real bolalarning ismi/rasmi** bo'lmasin (DON reytingi,
  profil) — demo profil ishlating. Android'ga xos narsalar (ilova
  statistikasi, batareya optimizatsiyasi) ko'rinmasin.

---

## 6. Qolgan bo'limlar

App Review Information (Notes), Age Rating, App Privacy, Export Compliance,
Pricing & Availability va topshirishdan oldingi tekshiruv ro'yxati —
`docs/APP_STORE_SUBMISSION_CHILD_IOS.md`.

> `ios/Runner/PrivacyInfo.xcprivacy` va App Store Connect'dagi App Privacy
> javoblari bir xil bo'lishi kerak. Biror funksiya qo'shilsa/olib tashlansa —
> ikkalasini birga yangilang.
