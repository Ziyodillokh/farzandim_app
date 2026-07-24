// ignore_for_file: avoid_escaping_inner_quotes
// O'zbek tilidagi matnda ko'p apostroflar ('') bor — har birini
// `"..."` bilan yozish o'qish qiyinligi va xato xavfini oshiradi.
// Maxfiylik siyosati va Foydalanish shartlari matni (o'zbekcha).
//
// Bu matn template: Play Market talabi uchun yetarli, lekin production
// launch oldidan yurist ko'rib chiqishi kerak. Sana va kontakt
// `_signatureDate` / `_contactEmail` orqali markazlashtirilgan — shu
// yerdan o'zgartirilsa barcha ekranlarda yangilanadi.

const String _signatureDate = '2026-05-12';
const String _contactEmail = 'shahlomansurovat@gmail.com';
const String _appName = 'Parvoz';
const String _legalEntity = 'Parvoz jamoasi (O\'zbekiston, Toshkent)';

/// Maxfiylik siyosati / Foydalanish shartlari ekranlari uchun bo'lim.
class LegalSection {
  const LegalSection(this.title, this.body);

  /// Bo'lim sarlavhasi (raqamlangan: "1. Kirish").
  final String title;

  /// Asosiy matn — bir necha paragraf, `\n\n` bilan ajratilgan.
  final String body;
}

/// Maxfiylik siyosati va Foydalanish shartlari ekranlarining matni.
abstract final class LegalText {
  /// Saytdagi oxirgi yangilanish sanasi.
  static const String lastUpdated = _signatureDate;

  /// Foydalanuvchi murojaat qila oladigan email.
  static const String contactEmail = _contactEmail;

  /// Maxfiylik siyosati sarlavhasi.
  static const String privacyPolicyTitle = 'Maxfiylik siyosati';

  /// Foydalanish shartlari sarlavhasi.
  static const String termsOfServiceTitle = 'Foydalanish shartlari';

  /// Maxfiylik siyosati — 11 ta bo'lim.
  static const List<LegalSection> privacyPolicy = [
    LegalSection(
      '1. Kirish',
      '$_appName — ota-onalar va vasiylar uchun mo\'ljallangan oilaviy '
          'xavfsizlik va nazorat ilovasi. Ushbu maxfiylik siyosati '
          'biz qanday shaxsiy ma\'lumotlarni yig\'ishimiz, ulardan '
          'qanday foydalanishimiz va ularni qanday himoya qilishimizni '
          'tushuntiradi.\n\n'
          'Ilovadan foydalanishni boshlash orqali siz ushbu shartlarga '
          'rozilik bildirasiz. Agar siz biron bir bandga rozi '
          'bo\'lmasangiz, iltimos, ilovani ishlatmang.\n\n'
          'Mas\'ul shaxs: $_legalEntity. Aloqa: $_contactEmail.',
    ),
    LegalSection(
      '2. Yig\'iladigan ma\'lumotlar',
      'Biz quyidagi turdagi ma\'lumotlarni yig\'amiz:\n\n'
          'A) Ota-ona/vasiy ma\'lumotlari:\n'
          '   • Telefon raqami (Phone OTP autentifikatsiyasi uchun)\n'
          '   • Email manzili (ixtiyoriy, parol tiklash uchun)\n'
          '   • Profil ma\'lumotlari (ism, profil rasmi)\n'
          '   • Qurilma identifikatori (FCM token push xabarlar uchun)\n'
          '   • Qurilma turi va OS versiyasi (texnik nosozliklarni '
          'aniqlash uchun)\n\n'
          'B) Bolaga oid ma\'lumotlar (ota-ona kiritadi):\n'
          '   • Ism, yosh, jinsi\n'
          '   • Profil rasmi (ixtiyoriy)\n'
          '   • Joriy GPS joylashuv (bola qurilmasi ruxsati bilan)\n'
          '   • Wi-Fi tarmoq nomi (joylashuv aniqligini oshirish uchun)\n'
          '   • Foydalanilgan ilovalar va vaqtlari (cheklov '
          'sozlamalarini ta\'minlash uchun)\n'
          '   • Qurilma model va batareya holati\n\n'
          'Hech qanday ma\'lumot reklama yoki uchinchi tomonlarga '
          'sotish uchun ishlatilmaydi.',
    ),
    LegalSection(
      '3. Maqsad va huquqiy asos',
      'Ma\'lumotlar quyidagi maqsadlarda qayta ishlanadi:\n\n'
          '   • Bola xavfsizligini ta\'minlash (joylashuv kuzatuvi, '
          'geo-zona ogohlantirishlari)\n'
          '   • Ota-ona nazorati (ilova cheklovlari, jadval)\n'
          '   • Ovozli va video xabarlar (oila aloqasi)\n'
          '   • Akkaunt autentifikatsiyasi va xavfsizligi\n'
          '   • Ilovaning texnik ishlashini ta\'minlash\n\n'
          'Huquqiy asos:\n'
          '   • O\'zbekiston Respublikasi: ZRU-547 "Shaxsga doir '
          'ma\'lumotlar to\'g\'risida"gi qonun (02.07.2019) — 19-modda '
          '(voyaga yetmagan shaxslarga oid ma\'lumotlarni qayta ishlash '
          'qonuniy vakil roziligi asosida)\n'
          '   • COPPA (Children\'s Online Privacy Protection Act, AQSh): '
          'ota-onaning aniq roziligi (verifiable parental consent)\n'
          '   • GDPR (Yevropa hududidagi foydalanuvchilar uchun, agar '
          'qo\'llanilsa): qonuniy manfaat (Art. 6.1(f)) va bolaga oid '
          'ma\'lumotlar uchun ota-ona roziligi (Art. 8)',
    ),
    LegalSection(
      '4. Uchinchi tomon xizmatlari',
      'Ilova quyidagi tashqi xizmatlardan foydalanadi:\n\n'
          '   • Asosiy ma\'lumotlar O\'zbekistondagi shaxsiy serverda '
          'saqlanadi: PostgreSQL ma\'lumotlar bazasi + MinIO fayl '
          'saqlash (farzandimedu.uz). Autentifikatsiya — o\'z JWT '
          'tizimimiz.\n'
          '   • Eskiz (O\'zbekiston): SMS orqali tasdiqlash kodlari '
          '(OTP)\n'
          '   • Firebase (Google LLC): FAQAT bildirishnomalar (Cloud '
          'Messaging), nosozlik hisobotlari (Crashlytics), anonim '
          'statistika (Analytics), xavfsizlik (App Check). Firebase '
          'ma\'lumotlar bazasi/autentifikatsiyasi ISHLATILMAYDI.\n'
          '   • Mapbox / Yandex Maps: xaritalarni ko\'rsatish, '
          'geokodlash\n'
          '   • Google Play Integrity: ilova haqiqiyligini tasdiqlash '
          '(faqat Android, App Check orqali)\n'
          '   • Apple DeviceCheck: ilova haqiqiyligini tasdiqlash (faqat '
          'iOS, App Check orqali)\n\n'
          'Ushbu xizmatlar Google va Apple kompaniyalarining xususiy '
          'maxfiylik siyosatlariga binoan ishlaydi:\n'
          '   • Google: https://policies.google.com/privacy\n'
          '   • Firebase: https://firebase.google.com/support/privacy\n'
          '   • Apple: https://www.apple.com/legal/privacy/',
    ),
    LegalSection(
      '5. Ma\'lumotlarni saqlash muddati',
      'Ma\'lumotlar quyidagi muddatlarda saqlanadi:\n\n'
          '   • Faol akkaunt: akkount o\'chirilmaguncha\n'
          '   • Akkaunt o\'chirilgach: 30 kun ichida butunlay '
          'o\'chiriladi (server tomonida atomik ravishda)\n'
          '   • Zaxira nusxalar: server tomonida cheklangan muddat\n'
          '   • Tizim loglari: maksimum 1 yil (xavfsizlik va xato '
          'tahlili uchun)\n'
          '   • Audit log (forensic trail): akkount o\'chmaguncha\n\n'
          'Joylashuv va ilova foydalanish ma\'lumotlari real vaqtda '
          'saqlanadi, lekin 30 kundan eski geo-hodisalar va '
          'foydalanish ma\'lumotlari avtomatik tarzda arxivlanadi yoki '
          'o\'chiriladi.',
    ),
    LegalSection(
      '6. Bola ma\'lumotlari (maxsus himoya)',
      '13 yoshdan kichik bolalar uchun maxsus himoya choralari '
          'qo\'llaniladi:\n\n'
          '   • Bola ma\'lumotlari faqat ota-ona/vasiy aniq roziligi '
          'asosida yig\'iladi\n'
          '   • Faqat zaruriy ma\'lumotlar yig\'iladi (minimum '
          'necessary principle)\n'
          '   • Bola ma\'lumotlari HECH QACHON:\n'
          '       - reklama uchun ishlatilmaydi\n'
          '       - uchinchi tomonlarga sotilmaydi\n'
          '       - profiling yoki targeting uchun ishlatilmaydi\n'
          '       - texnik xizmatdan tashqari uchinchi tomon bilan '
          'baham ko\'rilmaydi\n\n'
          'Ota-ona istalgan vaqtda bola ma\'lumotlarini ko\'rishi, '
          'tahrirlashi yoki o\'chirishi mumkin (Sozlamalar → Bolalar '
          'boshqaruvi yoki Hisobni o\'chirish).\n\n'
          'Tushuntirma: Parvoz "parental control" toifasidagi ilova. '
          'Bola foydalanuvchi emas — vasiy mahsulot foydalanuvchisi. '
          'Bola qurilmasidagi ilova faqat ota-ona o\'rnatishi va '
          'sozlashi mumkin.',
    ),
    LegalSection(
      '7. Foydalanuvchi huquqlari',
      'Sizning huquqlaringiz:\n\n'
          '   • Yig\'ilgan ma\'lumotlarni ko\'rish: Sozlamalar → Profil '
          '(o\'zingiz) va Sozlamalar → Bolalar boshqaruvi (bola '
          'ma\'lumotlari)\n'
          '   • Tahrirlash: barcha kiritilgan maydonlar (ism, telefon, '
          'email, profil rasmi, bola ma\'lumotlari) tahrirlanadi\n'
          '   • O\'chirish: Sozlamalar → Hisobni butunlay o\'chirish '
          '(barcha ma\'lumotlar, jumladan bolaga oid, atomik tarzda '
          'o\'chiriladi)\n'
          '   • E\'tiroz bildirish: agar qayta ishlashga qarshi '
          'bo\'lsangiz, $_contactEmail manziliga yozing\n'
          '   • Eksport (kelajakdagi versiyada): ma\'lumotlarni JSON '
          'formatida yuklab olish imkoniyati qo\'shiladi\n\n'
          'Murojaat 30 kun ichida javob beriladi (GDPR Art. 12.3 '
          'uslubida).',
    ),
    LegalSection(
      '8. Xavfsizlik',
      'Ma\'lumotlar quyidagi texnik vositalar bilan himoyalangan:\n\n'
          '   • TLS 1.2+ shifrlash (barcha tarmoq trafigi)\n'
          '   • Serverda kirish nazorati (har bir so\'rov JWT token '
          'va egalik bo\'yicha tekshiriladi)\n'
          '   • Parollar bcrypt bilan xeshlanadi (ochiq saqlanmaydi)\n'
          '   • SMS OTP (Eskiz) orqali tasdiqlash\n'
          '   • Firebase App Check (Play Integrity / DeviceCheck) — '
          'reverse-engineered klientlarni bloklash\n'
          '   • Audit log (har akkaunt o\'zgartirish tarixi)\n'
          '   • Server-side cleanup (akkount o\'chirilgach atomik)\n\n'
          'Texnologik tahdidlar (ma\'lumotlar buzilishi va h.k.) yuz '
          'berganda, ta\'sirlangan foydalanuvchilar 72 soat ichida '
          'xabardor qilinadi (GDPR Art. 33-34 uslubida).',
    ),
    LegalSection(
      '9. O\'zgarishlar',
      'Ushbu maxfiylik siyosati vaqti-vaqti bilan yangilanishi mumkin. '
          'Muhim o\'zgarishlar bo\'lganda foydalanuvchilar ilova '
          'ichidagi bildirishnoma va/yoki email orqali xabardor '
          'qilinadi.\n\n'
          'Yangilanish sanasi har bir versiyada yangilanadi (sahifaning '
          'yuqori qismida ko\'rsatilgan). Foydalanishni davom ettirish '
          'yangi shartlarga rozilik bildirish hisoblanadi.',
    ),
    LegalSection(
      '10. Aloqa',
      'Maxfiylik bilan bog\'liq savol yoki shikoyatlaringiz uchun:\n\n'
          '   • Email: $_contactEmail\n'
          '   • Pochta manzili: $_legalEntity, Toshkent shahri\n\n'
          'O\'zbekiston Respublikasida ma\'lumotlarni qayta ishlash '
          'vakolatli organi — Davlat ma\'lumotlarni himoya qilish '
          'agentligi. Agar shikoyatingiz qondirilmagan deb hisoblasangiz, '
          'shu organga murojaat qila olasiz.',
    ),
    LegalSection(
      '11. Yuridik holat',
      'Ushbu maxfiylik siyosati O\'zbekiston Respublikasi qonunlariga '
          'binoan tartibga solinadi. Nizolar Toshkent shahar sudida '
          'ko\'rib chiqiladi.\n\n'
          'Ushbu hujjat $_signatureDate sanasida kuchga kirgan. '
          'So\'nggi yangilanish: $_signatureDate.',
    ),
  ];

  /// Foydalanish shartlari — 11 ta bo'lim.
  static const List<LegalSection> termsOfService = [
    LegalSection(
      '1. Shartlarni qabul qilish',
      '$_appName ilovasini yuklab olib, o\'rnatib yoki '
          'foydalanish boshlash orqali siz ushbu Foydalanish '
          'shartlariga (keyingi o\'rinlarda "Shartlar") va Maxfiylik '
          'siyosatiga rozilik bildirasiz.\n\n'
          'Ilova faqat 18 yoshdan katta shaxslar (ota-ona yoki qonuniy '
          'vasiy) tomonidan o\'rnatilishi va foydalanilishi mumkin. '
          'Voyaga yetmaganlarning mustaqil foydalanishi taqiqlanadi.',
    ),
    LegalSection(
      '2. Xizmat tavsifi',
      '$_appName — bola xavfsizligi va ota-ona nazoratiga '
          'mo\'ljallangan ikki tomonlama (Parent App + Child App) '
          'tizim. Asosiy funksiyalar:\n\n'
          '   • Real vaqtdagi joylashuv kuzatuvi (faqat ota-ona '
          'qurilmasida)\n'
          '   • Geo-zona ogohlantirishlari (uy, maktab va h.k.)\n'
          '   • Ovozli va video xabarlar (oila aloqasi)\n'
          '   • Ilova foydalanish vaqtini cheklash (jadval)\n'
          '   • Jadval bo\'yicha eslatmalar\n'
          '   • Quick action (foto so\'rov, qurilma sozlamalari)',
    ),
    LegalSection(
      '3. Foydalanish shartlari',
      'Siz ushbu xizmatdan FAQAT quyidagi maqsadlarda foydalana olasiz:\n\n'
          '   • O\'z bolangiz xavfsizligini ta\'minlash\n'
          '   • Vasiylik huquqi doirasidagi voyaga yetmagan shaxslar '
          'ustidan qonuniy nazorat o\'rnatish\n\n'
          'Quyidagi xatti-harakatlar QATIY TAQIQLANADI:\n\n'
          '   • Boshqa odamning bolasini ota-ona ruxsatisiz kuzatish\n'
          '   • Voyaga yetgan shaxsni (jumladan, sherigi, qarindoshi) '
          'ruxsatisiz kuzatish (stalking)\n'
          '   • Ilovani spyware sifatida ishlatish\n'
          '   • Boshqa foydalanuvchilarga zarar etkazish\n'
          '   • Ilovaga reverse engineering yoki o\'zgartirish kiritish\n'
          '   • APK\'ni qayta tarqatish\n\n'
          'Shartlarga rioya qilmaslik akkountni darhol bekor qilishga '
          'olib keladi.',
    ),
    LegalSection(
      '4. Ota-ona javobgarligi',
      'Ota-ona/vasiy quyidagilarga javobgardir:\n\n'
          '   • Kiritilgan ma\'lumotlar to\'g\'riligi va to\'liqligi\n'
          '   • Bola bilan ochiq muloqot — kuzatuv haqida xabardor '
          'qilish (yoshiga mos)\n'
          '   • Bola maxfiyligini hurmat qilish va ma\'lumotlarni '
          'uchinchi shaxslarga oshkor qilmaslik\n'
          '   • Qurilmaga jismoniy kirish va parol himoyasi\n\n'
          'Tavsiya: bola yoshi va etukligiga qarab kuzatuv mavjudligi '
          'haqida xabardor qiling. Bu ishonchli muloqot va sog\'lom '
          'oilaviy munosabatlarning asosidir.',
    ),
    LegalSection(
      '5. To\'lov va obuna',
      'Hozirda $_appName bepul Beta versiyada taqdim etilmoqda. '
          'Kelajakdagi versiyalarda quyidagi xizmatlar pullik bo\'lishi '
          'mumkin:\n\n'
          '   • Qo\'shimcha bolalar (1-tasi bepul, keyingilar pullik)\n'
          '   • Kengaytirilgan joylashuv tarixi\n'
          '   • Maxsus geo-zonalar\n'
          '   • Premium ovozli/video xabarlar\n\n'
          'Pullik xizmatlar joriy etilganda foydalanuvchilar oldindan '
          'xabardor qilinadi. Bepul rejimda ham asosiy funksiyalar '
          'mavjud bo\'ladi.',
    ),
    LegalSection(
      '6. Hisobni o\'chirish',
      'Foydalanuvchi istalgan vaqtda o\'z akkountini va barcha '
          'tegishli ma\'lumotlarni butunlay o\'chirib tashlashi mumkin:\n\n'
          '   Sozlamalar → Hisobni butunlay o\'chirish\n\n'
          'O\'chirish jarayoni:\n'
          '   • Server tomonida atomik bajariladi\n'
          '   • Profil, bola hisoblari, xabarlar, geo-zonalar, '
          'jadvallar — hammasi o\'chiriladi\n'
          '   • Storage fayllar (foto, audio, video) ham olib '
          'tashlanadi\n'
          '   • Server bazasidagi foydalanuvchi yozuvi o\'chiriladi\n\n'
          'O\'chirish QAYTARIB BO\'LMAYDI. O\'chirilgandan keyin '
          'qaytadan ro\'yxatdan o\'tish yangi akkount yaratadi — eski '
          'ma\'lumotlar tiklanmaydi.',
    ),
    LegalSection(
      '7. Mas\'uliyat cheklovi',
      '$_appName "AS IS" (bor holida) tarzda taqdim etiladi. '
          '$_legalEntity quyidagi holatlarga javobgar emas:\n\n'
          '   • Internet aloqasi yo\'qligi yoki sekinligi\n'
          '   • GPS signali aniqsizligi yoki yo\'qligi\n'
          '   • Bola qurilmasining nosozligi yoki batareya tugashi\n'
          '   • Uchinchi tomon xizmatlarining nosozliklari (Firebase, '
          'Google Maps va h.k.)\n'
          '   • Foydalanuvchining noto\'g\'ri sozlamalari natijasidagi '
          'oqibatlari\n\n'
          'Ilova bola xavfsizligini ta\'minlovchi yagona vosita '
          'emas — uni boshqa xavfsizlik choralari (suhbat, '
          'tarbiya, jismoniy nazorat) bilan birga qo\'llang.',
    ),
    LegalSection(
      '8. Intellektual mulk',
      '$_appName ilovasi, logo, brend va barcha tegishli kontent '
          '$_legalEntity yoki uning litsenziya beruvchilarining '
          'mualliflik huquqi bilan himoyalangan.\n\n'
          'Quyidagilar TAQIQLANADI:\n'
          '   • Ilova kodini reverse engineering qilish\n'
          '   • Logo va brendni ruxsatsiz ishlatish\n'
          '   • APK\'ni qayta paketlash va boshqa nom bilan tarqatish\n'
          '   • Source code\'ni nusxalash yoki nashr etish\n\n'
          'Bunday xatti-harakatlar O\'zbekiston Respublikasining '
          'mualliflik huquqi to\'g\'risidagi qonunchiligi va xalqaro '
          'shartnomalarga binoan javobgarlikni keltirib chiqaradi.',
    ),
    LegalSection(
      '9. Shartlarni o\'zgartirish',
      '$_legalEntity ushbu Shartlarni vaqti-vaqti bilan yangilash '
          'huquqini saqlab qoladi. Muhim o\'zgarishlar haqida '
          'foydalanuvchilar:\n\n'
          '   • Ilova ichidagi bildirishnoma orqali\n'
          '   • Profil bilan bog\'langan email orqali (mavjud bo\'lsa)\n\n'
          'kamida 14 kun oldin xabardor qilinadi. O\'zgarishlardan '
          'so\'ng foydalanishni davom ettirish yangi shartlarga '
          'rozilikni anglatadi. Agar yangi shartlarga rozi bo\'lmasangiz, '
          'akkountni o\'chiring.',
    ),
    LegalSection(
      '10. Qonuniy huquq va nizolar',
      'Ushbu Shartlar O\'zbekiston Respublikasi qonunlariga binoan '
          'tartibga solinadi va talqin qilinadi.\n\n'
          'Foydalanuvchi va $_legalEntity o\'rtasida kelib chiqishi '
          'mumkin bo\'lgan nizolar avval do\'stona muzokara orqali hal '
          'qilinishga harakat qilinadi ($_contactEmail). Kelishuvga '
          'erishilmagan taqdirda, nizo Toshkent shahar sudida ko\'rib '
          'chiqiladi.',
    ),
    LegalSection(
      '11. Aloqa va sana',
      'Savol yoki murojaatlar uchun:\n\n'
          '   • Email: $_contactEmail\n'
          '   • Texnik yordam: Sozlamalar → Texnik yordam\n\n'
          'Ushbu Shartlar $_signatureDate sanasida kuchga kirgan. '
          'So\'nggi yangilanish: $_signatureDate.',
    ),
  ];
}
