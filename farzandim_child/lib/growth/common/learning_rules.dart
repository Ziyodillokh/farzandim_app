// Ekranlarda ko'rsatiladigan o'qish qoidalari (server bilan bir xil bo'lishi shart).

/// Bitta fan bo'yicha kunlik mashq taxminan shuncha daqiqa (10 savol).
const kMinutesPerSubject = 5;

/// Server qoidasi (backend `learning/domain/rewards.ts`): har to'g'ri javobga
/// 2 DON, hammasi to'g'ri bo'lsa +10. DON faqat kunning birinchi urinishiga.
const kDonPerCorrect = 2;
const kPerfectBonusDon = 10;

/// Bitta kunlik mashqdan olish mumkin bo'lgan eng ko'p DON.
int maxDonFor(int questionCount) =>
    questionCount <= 0 ? 0 : questionCount * kDonPerCorrect + kPerfectBonusDon;

/// 1–4-sinflar — soddalashtirilgan rejim (B03, U05, U20): katta matn va tugmalar.
const kEarlyGradeMax = 4;

bool isEarlyGrade(int? grade) => grade != null && grade <= kEarlyGradeMax;
