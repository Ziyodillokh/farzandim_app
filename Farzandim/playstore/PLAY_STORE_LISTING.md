# Farzandim (Ota-ona) — Google Play Console to'ldirish varag'i

> Bu hujjat Play Console'ga **copy-paste** uchun. Har bo'limni tegishli Console
> maydoniga kiriting. Texnik artefaktlar (AAB, ikonka) `playstore/` va
> `build/app/outputs/bundle/release/` da.

---

## 0. Ilova identifikatori
| Maydon | Qiymat |
|---|---|
| App name | **Farzandim** |
| Package (applicationId) | `com.farzandim.parent` |
| versionName / versionCode | `1.0.0` / `1` |
| Kategoriya | Parenting (yoki Tools) |
| Bepul/Pullik | Bepul |
| Reklama bormi | **Yo'q** (ilovada reklama yo'q) |

---

## 1. Maxfiylik va o'chirish URL'lari (App content)
| Console maydoni | Qiymat |
|---|---|
| Privacy policy URL | `https://farzandimedu.uz/privacy.html` |
| Data deletion (App content → Data deletion) | `https://farzandimedu.uz/account-deletion.html` |

---

## 2. Qisqa tavsif (Short description, ≤80 belgi)

**UZ:** `Farzandingiz xavfsizligi: jonli joylashuv, geo-zona, SOS va oilaviy aloqa.`

**RU:** `Безопасность ребёнка: геолокация, гео-зоны, SOS и семейная связь.`

**EN:** `Your child's safety: live location, geo-zones, SOS and family chat.`

---

## 3. To'liq tavsif (Full description, ≤4000 belgi)

### UZ
```
Farzandim — O'zbekiston oilalari uchun yaratilgan oilaviy xavfsizlik va aloqa ilovasi. Ota-onalarga farzandlari xavfsizligini xotirjam kuzatish va ular bilan yaqin aloqada bo'lish imkonini beradi.

ASOSIY IMKONIYATLAR:
• Jonli joylashuv — farzandingiz qayerdaligini xaritada real vaqtda ko'ring
• Geo-zonalar — uy, maktab kabi joylar uchun kirish/chiqish bildirishnomalari
• SOS — favqulodda holatda farzandingiz signal yuborsa, darhol xabar olasiz
• Ovozli va video xabarlar — oila bilan xavfsiz yozishmalar
• Jadval va ilova cheklovlari — sog'lom ekran vaqti odatlari
• Faollik va batareya holati — bir qarashda muhim ma'lumot

NIMA UCHUN FARZANDIM?
Ilova maxsus ota-onalar uchun mo'ljallangan. Farzandingiz ma'lumotlari hech qachon reklama uchun ishlatilmaydi yoki uchinchi tomonlarga sotilmaydi. Barcha ma'lumot shifrlangan holda uzatiladi.

MUHIM:
Farzandim — ota-onalar uchun nazorat ilovasi (18+). Faqat o'z farzandingizni, uning xabardorligi bilan kuzatish uchun mo'ljallangan. Ilovani o'rnatish va sozlash faqat ota-ona/qonuniy vasiy zimmasida.

Savollar uchun: shahlomansurovat@gmail.com
Maxfiylik: https://farzandimedu.uz/privacy.html
```

### RU
```
Farzandim — приложение семейной безопасности и связи для семей Узбекистана. Помогает родителям спокойно следить за безопасностью детей и оставаться на связи.

ВОЗМОЖНОСТИ:
• Геолокация в реальном времени — где сейчас ваш ребёнок на карте
• Гео-зоны — уведомления о входе/выходе (дом, школа и т.д.)
• SOS — мгновенное оповещение в экстренной ситуации
• Голосовые и видео сообщения — безопасное общение в семье
• Расписание и ограничения приложений — здоровое экранное время
• Активность и заряд батареи — важное с одного взгляда

ПОЧЕМУ FARZANDIM?
Приложение создано для родителей. Данные ребёнка никогда не используются для рекламы и не продаются третьим лицам. Все данные передаются в зашифрованном виде.

ВАЖНО:
Farzandim — родительское приложение контроля (18+). Предназначено только для наблюдения за собственным ребёнком с его ведома. Установка и настройка — ответственность родителя/опекуна.

Вопросы: shahlomansurovat@gmail.com
Конфиденциальность: https://farzandimedu.uz/privacy.html
```

### EN
```
Farzandim is a family safety and communication app for families in Uzbekistan. It helps parents keep their children safe and stay closely connected.

KEY FEATURES:
• Live location — see where your child is on the map in real time
• Geo-zones — enter/exit alerts for places like home and school
• SOS — get notified instantly if your child sends an emergency signal
• Voice and video messages — safe family messaging
• Schedules and app limits — healthy screen-time habits
• Activity and battery status — what matters at a glance

WHY FARZANDIM?
Built specifically for parents. Your child's data is never used for advertising or sold to third parties. All data is transmitted encrypted.

IMPORTANT:
Farzandim is a parental control app (18+). Intended only to monitor your own child, with their awareness. Installation and setup are the responsibility of the parent/legal guardian.

Questions: shahlomansurovat@gmail.com
Privacy: https://farzandimedu.uz/privacy.html
```

---

## 4. Grafik aktivlar (Store listing → Graphics)
| Aktiv | Talab | Holat |
|---|---|---|
| App icon | 512×512 PNG | ✅ `playstore/play_icon_512.png` |
| Feature graphic | 1024×500 PNG/JPG | ⏳ dizayn kerak (brend: #0A0A12 fon + #C5F562 lime + "Farzandim") |
| Phone screenshots | 2–8 ta, ≥1080px | ⏳ ishlab turgan ilovadan (Dashboard, Xarita, Geo-zona, Ovozli xabar, Sozlamalar) |

> Skrinshot olishda real telefon raqami/aniq manzil ko'rinmasin (test ma'lumot ishlating).

---

## 5. Data Safety formasi (App content → Data safety)

**Does your app collect or share user data?** → **Yes**

**Is all data encrypted in transit?** → **Yes** (HTTPS/WSS)
**Do you provide a way to request data deletion?** → **Yes** (in-app + https://farzandimedu.uz/account-deletion.html)

### Yig'iladigan ma'lumot turlari:
| Data type | Collected | Shared | Purpose | Izoh |
|---|---|---|---|---|
| **Location → Precise location** | Yes | Yes | App functionality | Bola joyi, oila a'zolari ko'radi |
| Personal info → Name | Yes | No | Account management, App functionality | |
| Personal info → Email | Yes | No | Account management | |
| Personal info → Phone number | Yes | No | Account management | |
| Photos and videos | Yes | Yes | App functionality | Video xabar, bola fotosi |
| Audio → Voice or sound recordings | Yes | Yes | App functionality | Ovozli xabar |
| Messages → In-app messages | Yes | Yes | App functionality | Oila chati |
| App activity → App interactions | Yes | No | App functionality | Bola ilova-faolligi (cheklov) |
| Device/IDs → Device or other IDs | Yes | No | App functionality | FCM token (push) |

> "Shared" = oila a'zolari o'rtasida ilova funksiyasi orqali; reklama/sotuv uchun EMAS.
> Har turi uchun: **"Data can't be deleted" EMAS** → foydalanuvchi o'chira oladi.
> Uchinchi tomon SDK (Firebase/Google) bilan ishlov beriladi.

---

## 6. Content rating (App content → Content rating, IARC anketa)
| Savol | Javob |
|---|---|
| Category | Utility / Communication / Other (Tools) |
| Foydalanuvchilar muloqot/kontent ulashadimi? | **Ha** (oila chati, ovoz/video) |
| Joylashuv ulashiladimi? | **Ha** (oila ichida) |
| Zo'ravonlik/jinsiy/qimor/giyohvand kontent | **Yo'q** |
| Foydalanuvchi yaratgan kontent moderatsiyasi | Faqat oila ichida, ommaviy emas |

> Rost javob bering — natija odatda "Everyone / PEGI 3" atrofida bo'ladi.

---

## 7. Target audience and content (App content)
| Maydon | Qiymat |
|---|---|
| Target age group | **Faqat 18+ (kattalar)** |
| Designed for Families dasturi | **YO'Q** (qo'shmang) |
| Appeals to children? | **No** (bu kuzatuvchi ota-ona ilovasi) |

> Sabab: ilova ota-ona qurilmasida ishlaydi va voyaga yetganlar uchun. Bolalarga
> yo'naltirilgan deb belgilash noto'g'ri va qattiqroq tekshiruvga olib keladi.

---

## 8. Boshqa App content deklaratsiyalari
| Bo'lim | Javob |
|---|---|
| Ads | Ilovada reklama yo'q |
| Government app | Yo'q |
| Financial features | Yo'q |
| Health | Yo'q |
| Permissions — sezgir/cheklangan | Background location / SMS / Call log YO'Q (faqat kamera, mikrofon, bildirishnoma, foto — barchasi just-in-time) |
| App access (test login) | Reviewer uchun test akkaunt bering: telefon raqami + OTP yoki tayyor login |

> **MUHIM:** Reviewer ilovaga kira olishi uchun **test akkaunt** (App access bo'limida)
> bering — aks holda "login qila olmadik" deb rad etiladi.
