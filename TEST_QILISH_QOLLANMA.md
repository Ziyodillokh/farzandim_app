# Farzandim — har bir funksiyani test qilish qo'llanmasi

> DUYO AI (#64–70) hozir yo'q — qolgan hammasini qanday sinashni o'rgatadi.
> Format: **Qadam** → **Kutilgan natija ✅**

---

## 0. TAYYORGARLIK (avval shu)
1. Backend ishlab tursin: `http://10.254.131.67:3000` (yoki localhost). Tekshiruv: brauzerда `…:3000/api/docs` ochilsa — ✅.
2. **Ota-ona** akkaunti: ro'yxatdan o'ting yoki kiring.
3. **Bola**: ota-onada bola qo'shing → oila kodi oling → bola ilovasида kod kiriting (pair).
4. Ikkala ilova ochiq tursin (web'da 2 brauzer oynasi yoki Android'da 2 qurilma).
5. ⚠️ Web'da nazorat/fon/native (screen-time, bloklash, location, SOS native) **ishlamaydi** — ularni **Android APK**да sinang.

---

## 1. Hisob, pairing, rozilik (#1–5)
- **#1 Child profile** — ota-onada "Bola qo'shish" → ism/yosh/hudud/foto → saqlang → **dashboard'да bola ko'rinadi** ✅
- **#2 Pairing** — bola "Kodni kiriting" → kod → **bola dashboard'ga o'tadi**, ota-onada "ulandi" ✅
- **#3 QR/kod** — bola "QR orqali ulash" → ota-ona kodini skan → **ulanadi** ✅
- **#4 Consent** — bola ilk ochilishда rozilik oynasi → "Roziman" → **bir marta, qayta chiqmaydi** ✅
- **#5 Onboarding** — bola pair'dan keyin qiziqishlar/slaydlar → **bir marta ko'rsatiladi** ✅

## 2. Screen time (#6–12) — **Android kerak**
- **#6 Daily screen time** — bola telefonда ilovalarni ishlatib turing → ota-ona "Faollik/App cheklovlari"да **bugungi umumiy vaqt** ✅
- **#7 Haftalik statistika** — shu ekranда **7 kunlik grafik** ✅
- **#8 App usage minutes** — har ilova yonida **necha daqiqa** ✅
- **#9 Eng ko'p ishlatilgan** — ro'yxat **ko'pdan-kamga** tartiblangan ✅
- **#10 Daily limit** — ota-ona ilovaga kunlik limit qo'ysin → bola o'sha vaqtни sarflasa → **ilova bloklanadi** ✅
- **#11 Bedtime** — ota-ona uyqu vaqti (22:00–07:00) qo'ysin → o'sha oraliqда **bloklanadi** ✅
- **#12 Vaqt tugadi ogohlantirish** — limit tugaganда bola ekranида **"🌙 Bugungi vaqt tugadi" + Ruxsat so'rash** ✅

## 3. App control (#13–18) — **Android kerak**
- **#13 Selected app block** — ota-ona bitta ilovani tanlab bloklasin → bola **o'sha ilovani ocholmaydi** ✅
- **#14 Category block** — "Ijtimoiy tarmoqlar"ni bloklasin → o'sha kategoriya ilovalari **bloklanadi** ✅
- **#15 Remote instant block** — ilovaga uzun bosib "Darhol blokla" → **bir necha soniyada** bola telefonида blok ✅
- **#16 Unlock request** — bola bloklangan ilovada "Ruxsat so'rash" → **ota-onaga push keladi** ✅
- **#17 Approve/deny** — ota-ona "Rad et" yoki "Vaqt ber" → bola **xabar oladi** ✅
- **#18 Extra time 5–60 daq** — ota-ona 30 daq bersin → bola **30 daq o'sha ilovani ochadi**, keyin yana bloklanadi ✅

## 4. Web / xavfsiz kontent (#19–22)
- **#19 Web filter** — ota-ona qurilma sozlamasида "Xavfsiz internet" yoqsin (Android) → **Private DNS tavsiya/cheklov** ✅
- **#20 Kategoriya cheklov** — "Kattalar/qimor" yoqilsin → o'sha turdagi saytlar **cheklanadi** (Android) ✅
- **#21 Xavfsiz kontent tavsiyasi** — bola "Videolar/Content"da → **faqat tasdiqlangan kontent** ✅
- **#22 Yoshga mos** — bola yoshини o'zgartiring → feed **boshqa kontent** ko'rsatadi ✅

## 5. Lokatsiya / xavfsizlik (#23–29) — **Android kerak**
- **#23 Live location** — ota-ona "Joylashuv" → **bola xaritada real-time** ✅
- **#24 Location history** — "Tarix" → **harakat chizig'i** ✅
- **#25/26 Safe Zone / uy-maktab** — geo-zona qo'shing (radius) → **xaritada doira** ✅
- **#27 Zona kirish/chiqish** — bola zonaга kirsa/chiqsa → ota-onaga **push** ✅
- **#28 SOS tugma** — bola SOS bossin → ota-onaga **darhol signal** ✅
- **#29 SOS + location** — SOS bilan **qayerda bosgani** keladi ✅

## 6. Aloqa nazorati (#30–36)
- **#30 Heartbeat/last seen** — bola ilovani ochiq tutsin → ota-ona dashboard'да **"online"** ✅
- **#31 Aloqa uzildi statusi** — bola internetни o'chirsin → ~5 daq → dashboard'да **"Aloqa uzildi" (sariq)** ✅
- **#32/33 Push** — 10 daq o'tsa ota-onaga **aynan**: *"Parvoz app bilan aloqa uzildi. Ilova o'chirilgan, internet uzilgan yoki telefon faol emas bo'lishi mumkin."* ✅
- **#34 Parent'ga push** — yuqoridagi push keladi ✅
- **#35 Last seen vaqti** — "oxirgi faol: X daqiqa oldin" ✅
- **#36 Online/offline** — holat rangli ko'rsatkich ✅
> Tez sinash: men oldin Prisma Studio orqali ko'rsatgandim — `lastSeenAt`ni 15 daq orqaga qo'ysangiz, ~3 daqiqada push chiqadi.

## 7. Device status (#37–43)
- **#37 Battery** — ota-ona dashboard/qurilmaда **batareya %** ✅ (Android)
- **#38 Internet status** — wifi/mobil holati ✅
- **#39–41 Ruxsat statuslari** — bola ruxsat bersin/bermasin → ota-onaда **yashil/qizil** holat ✅
- **#42 Accessibility** — faqat Android: holat ko'rinadi ✅ (iOS'da yo'q)
- **#43 Permission changed** — bola location ruxsatини **o'chirsin** → ~1 daq → ota-onaga **"ruxsat o'chirildi" push** ✅

## 8. Ta'limiy kontent (#44–49)
- **#44 Video** — bola "Videolar" → ochib ko'ring (oddiy + **YouTube** — Xato 153 chiqmasligi kerak) ✅
- **#45 Audiokitob** — "Audiokitoblar" → eshiting ✅
- **#46 Kutubxona** — "Kitoblar" → PDF ochiladi ✅
- **#47 Yoshga mos** — yosh bo'yicha filtr ✅
- **#48 Maqolalar** — "Maqolalar" tab → markdown matn ochiladi ✅
- **#49 Tavsiya** — "Siz uchun / Tavsiya" bo'limi ✅
> Eslatma: kontent ko'rinishi uchun **admin panelдан video/kitob/maqola qo'shilgan** bo'lishi kerak.

## 9. Test / olimpiada / reyting (#50–56)
- **#50 Online test** — bola "Konkurslar" → test boshlash ✅
- **#51 Olimpiada** — fan bo'yicha olimpiada ro'yxati ✅
- **#52 Konkurs** — konkursга qatnashish ✅
- **#53 Timer** — savol vaqti sanaydi, tugaganда keyingiga o'tadi ✅
- **#54 Natija** — test oxirida **ball/foiz** ✅
- **#55 Reyting** — "Reyting" → **platformadagi bolalar** (nick bilan) ✅
- **#56 Sertifikat** — 80%+ to'plasa → **"Sertifikat" tugma** → ko'rish/ulashish ✅
> Sinash uchun admin paneldан **olimpiada qo'shilgan** bo'lishi kerak.

## 10. Gamifikatsiya (#57–63)
- **#57 XP** — test/faollikdan keyin **XP oshadi** ✅
- **#58 Level** — XP yetganда **daraja oshadi** ✅
- **#59 Achievement** — yutuqlar ro'yxati ✅
- **#60 Streak** — har kunlik faollik → streak sanaydi ✅
- **#61 Badge** — belgilangan natijada badge ✅
- **#62 Progress** — profil/analitikада progress grafigi ✅
- **#63 Rivojlanish ko'rsatkichi** — dashboard/profilда **yaxlit indeks + trend** ✅

## 12. Bildirishnomalar (#71–77)
- **#71 Parent→child push** — ota-ona xabar/so'rov yuborsin → bola **push** oladi ✅
- **#72 Child→parent signal** — bola SOS/javob → ota-ona **signal** ✅
- **#73 SOS push** — #28 bilan birga ✅
- **#74 Unlock push** — #16 bilan birga ✅
- **#75 Location alert** — #27 bilan birga ✅
- **#76 Aloqa uzildi push** — #32 bilan birga ✅
- **#77 Kontent/test eslatma** — belgilangan vaqtда bolaga eslatma push (dars 16:00 / sport 18:00) ✅

---

## Qaysi muhitда test qilinadi
| Bloklar | Web (hozir) | Android APK |
|---|---|---|
| 1, 4, 8, 9, 10, 12 (kontent/test/gamifikatsiya/auth/bildirishnoma) | ✅ | ✅ |
| 2, 3, 5, 6, 7 (screen-time, bloklash, location, device status, fon) | ❌ | ✅ |

**Eng to'liq sinov:** Android APK + 2 qurilma (ota-ona + bola). APK fonда tayyorlanmoqda.
