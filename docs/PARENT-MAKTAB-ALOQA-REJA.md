# Ota-ona ilovasi: Maktab bo'limi ichki sahifalari va maktab bilan aloqa — reja

Sana: 2026-11-09. Egasining so'rovi:
- Maktab tabidagi kartalar bosilganda ochiladigan sahifalar (E'lonlar, To'lovlar,
  Davomat) ideal va professional bo'lsin.
- "Maktab bilan bog'lanish": kim bilan (direktor, psixolog, sinf rahbari, fan
  o'qituvchisi) — ro'yxatdan tanlanadi. Har bir odam ichida unga mos xabar
  shablonlari bo'ladi, ota-ona o'zi ham yoza oladi.
- Bolaning maktabdagi statistikasi Maktab bo'limida bo'lsin.
- Barcha UI dizayn kanvasiga (artifact) chiqariladi.

## Qarorlar

1. **Kontaktlar ro'yxati maktab ma'lumotidan quriladi** (qo'lda kiritilmaydi):
   - Sinf rahbari: o'quvchi sinfining rahbari.
   - Fan o'qituvchilari: shu sinfga biriktirilgan O'qituvchi rolidagi xodimlar.
     Fan nomi xodimning lavozimidan olinadi.
   - Rahbariyat: Direktor va Ma'muriyat (Admin).
   - Psixolog: maktabning barcha faol psixologlari.
   - Navbatchi ro'yxatda yo'q.
   - Faqat **panel hisobi bor** va faol xodim ko'rinadi, aks holda xabar hech
     kimga yetib bormaydi.
   - Xodim telefoni ota-onaga ko'rsatilmaydi: aloqa faqat ilova orqali.
2. **Murojaat (thread)** = ota-ona + xodim + o'quvchi.
   - Mavzu (shablon kaliti) birinchi xabarda tanlanadi.
   - Bir juftlikda bitta ochiq murojaat bo'ladi; ota-ona yozsa, hal qilingan
     murojaat qayta ochiladi.
   - Xabarni **faqat qabul qiluvchi xodim** ko'radi. Direktor psixolog yoki
     o'qituvchi yozishmalarini ko'rmaydi.
   - Matn bazada AES-256-GCM bilan shifrlanadi (g'amxo'rlik moduli kabi).
3. **Shablonlar rolga qarab** ilovada (uz/ru/en). Server faqat mavzu kalitini
   tekshiradi:
   - Sinf rahbari: kelmaydi, erta olib ketaman, uy vazifasi, o'zlashtirish,
     uchrashuv.
   - Fan o'qituvchisi: fandan o'zlashtirish, uy vazifasi, qo'shimcha dars.
   - Direktor: uchrashuv, taklif, muammo, minnatdorchilik.
   - Ma'muriyat: to'lov, ma'lumotnoma/hujjat.
   - Psixolog: kayfiyat, bulling xavotiri, maslahat — "maxfiy" belgisi bilan.
4. **Cheklovlar:**
   - xabar 1–1000 belgi (xodim javobi 1–2000);
   - kuniga 5 ta yangi murojaat va 30 ta xabar (429);
   - murojaat holatlari: Ochiq, Hal qilindi;
   - o'qildi belgisi ikki tomonlama.
5. **Bildirishnomalar:**
   - xodimga panel qo'ng'iroqchasi (`PARENT_MESSAGE`, faqat o'ziga);
   - ota-onaga xodim javob berganda push.
6. **To'lovlar:** platforma summa yoki qarz hisoblamaydi (TZ 4.5) — o'zgarmaydi.
   Sahifa sana mantiqiga quriladi:
   - holatlar: yaqinlashmoqda, bugun, muddati o'tdi, oldindan to'langan,
     to'xtatilgan, tekshirilmoqda;
   - "To'laganman" tuzilgan shakl bilan yuboriladi: usul, oy, chek raqami;
   - **to'lov tarixi** maktab yozuvlaridan ko'rsatiladi (xodim ID'si
     ko'rsatilmaydi).
7. **Statistika** (har o'quvchi uchun):
   - davomat: o'quv yili va oxirgi 30 kun; o'rtacha kelish vaqti; o'z vaqtida
     kelish seriyasi;
   - sinf o'rtachasi bilan solishtirish, faqat sinfda 5 va undan ortiq o'quvchi
     bo'lsa;
   - maktab topshiriqlari: berilgan, topshirilgan, qabul qilingan, qaytarilgan;
   - Parvoz Growth fanlari bo'yicha natija (bola ilovasi ulangan bo'lsa).
   - Reyting yoki boshqa bolalar bilan shaxsiy solishtirish yo'q.

## Ishlar

### A. Backend (`feat/parent-school-connect`, main'dan)
- [ ] Prisma: `SchoolParentThread` va `SchoolParentMessage` (faqat qo'shiladi,
      mavjud jadvalga tegilmaydi).
- [ ] `GET /parent/school/contacts?studentId=`.
- [ ] Ota-ona murojaatlari:
      `GET|POST /parent/school/threads`,
      `GET /parent/school/threads/:id`,
      `POST /parent/school/threads/:id/messages`,
      `POST /parent/school/threads/:id/read`.
- [ ] Xodim murojaatlari:
      `GET /school/parent-threads`,
      `GET /school/parent-threads/:id`,
      `POST /school/parent-threads/:id/messages`,
      `POST /school/parent-threads/:id/read`,
      `POST /school/parent-threads/:id/status`.
      Yangi ruxsat: `inbox.parents` (Navbatchidan boshqa barcha rollar).
- [ ] E'lonlar javobiga qo'shiladi: `from` (rol va lavozim) va `audience`
      (butun maktab yoki sinf nomlari).
- [ ] To'lovlar javobiga `history` qo'shiladi (amal, sana, izoh).
- [ ] `GET /parent/school/students/:id/overview`: davomat, sinf o'rtachasi
      (K=5), topshiriqlar.
- [ ] Unit va e2e testlar (alohida `farzandim_parent_school_test` bazasi).

### B. Maktab paneli
- [ ] "Ota-onalar xabarlari" (`/inbox`):
  - ro'yxat va yozishma;
  - filtrlar: Ochiq, Hal qilingan;
  - tezkor javob shablonlari;
  - "Hal qilindi" tugmasi;
  - menyuda o'qilmaganlar soni.
- [ ] Mock (demo) va http servislar; demo yozishmalar; vitest va e2e.

### C. Ota-ona ilovasi (Flutter)
- [ ] Maktab tabi: "Maktab bilan bog'lanish" kartasi; o'quvchi kartasi
      statistikaga olib boradi.
- [ ] E'lonlar:
  - filtrlar: Barchasi, O'qilmagan, Muhim;
  - kun bo'yicha guruhlash;
  - batafsil sahifa: kimdan, kimga, "Sinf rahbariga savol".
- [ ] To'lovlar: holat kartasi, tuzilgan "To'laganman" varag'i, to'lov tarixi,
      "Ma'muriyatga yozish".
- [ ] Davomat:
  - farzand tanlash, oy halqasi, ko'rsatkichlar;
  - kelish vaqti va seriya;
  - rangli kalendar, kun tafsiloti;
  - kelmagan kun uchun "Sababini yozish".
- [ ] Bog'lanish: kontaktlar → shaxs sahifasi (shablonlar) → yozish → yozishma;
      "Murojaatlarim".
- [ ] "Farzandim maktabda" statistika sahifasi.
- [ ] Testlar va skrinshot harness sahifalari.

### D. Yakun
- [ ] Skrinshotlar kanvasga, yangi qator: "P2 · Maktab ichida".
- [ ] Backend va panel main'ga (deploy); ilova `feat/growth-v5` ga; APK.
