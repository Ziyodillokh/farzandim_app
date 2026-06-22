# Farzandim — funksiyalarni test qilish ro'yxati

> O'zingiz qo'lda test qilish uchun. Har bandni bajarib, ✅/❌ belgilang.
> Backend ishlab turishi shart (`http://10.254.131.67:3000` yoki `localhost:3000`).

---

# 👨‍👩‍👧 OTA-ONA ILOVASI (Farzandim)

## 1. Auth / kirish
- [ ] Ro'yxatdan o'tish (`/sign-up`) — email/parol bilan
- [ ] Kirish (`/sign-in`)
- [ ] Telegram orqali kirish (`/login-telegram`)
- [ ] Parolni unutdim (`/forgot-password`)
- [ ] Chiqish (Settings → chiqish)

## 2. Bola boshqaruvi
- [ ] Bola qo'shish (`/add-child`) — ism/yosh/hudud/foto
- [ ] Oila kodi ko'rsatish (`/family-code/:childId`) — bola ulashi uchun kod
- [ ] Bola tahrirlash (`/edit-child/:id`)
- [ ] Bir nechta bola boshqarish
- [ ] Akkaunt qo'shish (`/add-account`)
- [ ] Pair so'rovlari (`/pair-requests/:childId`) — re-pair tasdiqlash

## 3. Dashboard
- [ ] Asosiy dashboard (`/dashboard`) — bolalar ro'yxati + holat
- [ ] Bola jonli holati: online / **aloqa uzildi** / batareya
- [ ] Quick actions tugmalari

## 4. Joylashuv / xavfsizlik
- [ ] Jonli joylashuv xaritada (`/location/:childId`)
- [ ] Joylashuv tarixi (`/location/:childId/history`)
- [ ] Geo-zonalar ro'yxati (`/geo-zones/:childId`)
- [ ] Geo-zona qo'shish/tahrirlash (uy/maktab)
- [ ] Zona kirish/chiqish bildirishnomasi
- [ ] SOS signallari (`/sos-alerts`)

## 5. Nazorat (Android bola qurilmasi kerak)
- [ ] App cheklovlari (`/app-restrictions/:childId`)
- [ ] App limitlari (`/app-limits/:childId`) — kunlik vaqt
- [ ] **Darhol blokla** (ilovaga uzun bosish)
- [ ] **Kategoriya blok** (ijtimoiy/o'yin/video)
- [ ] **Unlock so'rovi** — bola so'raydi → tasdiq/rad + vaqt berish
- [ ] Jadvallar (`/schedules/:childId`) — uyqu/dars vaqti
- [ ] Qurilma sozlamalari (`/quick-actions/device/:childId`)
- [ ] **Xavfsiz internet** (web filtr) toggle
- [ ] **Ruxsat o'zgardi** ogohlantirishi

## 6. Aloqa
- [ ] Ovozli/video xabarlar (`/voice-messages`, `/quick-actions/voice/:childId`)
- [ ] Foto so'rovi (`/photo-requests/:childId`)
- [ ] Support chat (`/support`)
- [ ] Feedback (`/feedback/:childId`)

## 7. Hisobotlar / rivojlanish
- [ ] Haftalik hisobot (`/weekly-report/:childId`)
- [ ] Yutuqlar (`/achievements/:childId`)
- [ ] **Rivojlanish ko'rsatkichi** (development)
- [ ] Reyting (bola bilan bir xil XP)

## 8. Bildirishnomalar
- [ ] Bildirishnomalar markazi (`/notifications`)
- [ ] Push qabul qilish (SOS, geo-zona, aloqa uzildi, unlock, ruxsat)
- [ ] **Eslatma sozlamalari** (dars/sport/kontent yoqish-o'chirish)

## 9. Sozlamalar
- [ ] Sozlamalar (`/settings`), profil (`/settings/profile`)
- [ ] Til (`/language`), bolalar ro'yxati (`/settings/children`)
- [ ] Sessiyalar (`/settings/sessions`), akkaunt o'chirish (`/settings/delete-account`)
- [ ] Maxfiylik/shartlar (`/legal/...`)
- [ ] App update tekshirish

---

# 🧒 BOLA ILOVASI (Parvoz)

## 1. Ulanish / boshlash
- [ ] Welcome (`/welcome`) → Splash (`/splash`)
- [ ] Parent consent / rozilik (`/consent`)
- [ ] Onboarding / qiziqishlar (`/onboarding`)
- [ ] **Kod orqali ulash** (`/pairing`) — ota-onadan olingan kod
- [ ] **QR orqali ulash** (`/qr-scan`)
- [ ] Ulanish kutilmoqda (`/pair-waiting`) — ota-ona tasdiqi
- [ ] Ruxsatlar (`/permission-setup`, `/permissions`)

## 2. Dashboard / profil
- [ ] Asosiy dashboard (`/dashboard`) — XP/level/streak
- [ ] Profil (`/profile`), profil tahrirlash (`/account-edit`) — ism/yosh/hudud/**foto**
- [ ] SOS tugmasi → joylashuv bilan yuborish
- [ ] **Rivojlanish ko'rsatkichi**

## 3. Kontent / ta'lim
- [ ] Videolar (`/videos`) — feed, qidiruv, filtr
- [ ] Video player (`/video-player`) — oddiy + **YouTube** (Xato 153 yo'q)
- [ ] Audiokitoblar (`/audiobooks`) + player (`/audio-player`)
- [ ] Kitoblar/PDF (`/books`)
- [ ] **Maqolalar** (`/articles`) — markdown o'qish
- [ ] Content hub (`/content`) — barcha kontent
- [ ] Yoshga mos filtr ishlayaptimi

## 4. Test / olimpiada / reyting
- [ ] Konkurslar (`/contests`)
- [ ] Test boshlash (`/contest-start`) → quiz (`/contest-quiz`)
- [ ] Quiz timer + natija + 2-savoldan keyin qotmasligi
- [ ] **Sertifikat** (`/certificate`) — g'olibga
- [ ] **Reyting** (`/ranking`) — platformadagi bolalar ko'rinadi

## 5. Aloqa
- [ ] Ovozli chat (`/voice-chat`) — yozib yuborish
- [ ] Video xabar (`/video-recording`, `/video-preview`)
- [ ] Matn xabar — bubble matnga mos o'lchamda

## 6. Bildirishnomalar / boshqa
- [ ] Bildirishnomalar (`/notifications`) — **ota-onaga tegishli turlar ko'rinmaydi**, guruhlangan, ikonali
- [ ] Eslatma push (dars/sport/kontent)
- [ ] Jadvallar (`/schedules`)
- [ ] Analitika (`/analytics`)
- [ ] Sozlamalar (`/settings`)

## 7. Fon (chiqib ketganda — Android)
- [ ] Ilovani recent'dan o'chirib → joylashuv/heartbeat davom etadimi
- [ ] Telefon qayta yoqilganda xizmat tiklanadimi (BootReceiver)
- [ ] Qayta ochilganда pairing saqlanib qoladimi

---

## ⚠️ Eslatmalar
- **Android'da:** hamma funksiya ishlaydi (nazorat, fon, bloklash).
- **iOS'da:** nazorat funksiyalari (screen-time, bloklash, SIM, fon-location) ishlamaydi — Family Controls kerak.
- **Web (Chrome)'da:** nazorat/fon/native funksiyalar ishlamaydi (faqat kontent/ta'lim/aloqa).
- To'liq sinov uchun **Android APK + 2 qurilma** (ota-ona + bola) eng yaxshi.
