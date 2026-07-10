# Konkurslar (Contests) — Handoff (boshqa AI uchun)

> Farzandim **CHILD** ilovasi · `lib/features/contests/` · Flutter + Riverpod + go_router + Dio.
> Bola uchun olimpiada/konkurs platformasi: ro'yxat → 3-qadamli intro → savol-javob (timer + feedback) → natija → XP + sertifikat.
> Bu hujjat read-only tahlildan tuzilgan — katta o'zgarishdan oldin fayl:qatorni o'zing tasdiqla.

## 1. TL;DR — eng muhim 5 nuqta
1. **Data REAL** (backend `/content/olympiads`), lekin backend yiqilsa **`MockQuestions.all` (10 ta offline savol)** ga tushadi — bu holatda sertifikat yo'q (`attemptId=null`), UI ogohlantirmaydi.
2. **Styling holati:** feature global `AppColors`dan foydalanadi → `AppColors.primary` allaqachon **AQUA `#16B5C9`** (markaziy o'zgarish). LEKIN **Parvoz night/`_P` redizayniga O'TKAZILMAGAN** — hali Duolingo-uslubidagi **light** layout. Dashboard/notifications/profil kabi redizayn QILINMAGAN.
3. **G'olib chegarasi = 0.80 (80%)** — yagona manba `QuizState.winnerThreshold`. UI natija + XP + sertifikat — uchalasi shuni o'qiydi. O'zgartirsang, backend sertifikat chegarasi ham mos bo'lishi shart (aks holda "G'olib" ko'rinadi-yu sertifikat 403).
4. **Anti-cheat:** backend `correctIndex = -1` qaytaradi → har javob `POST .../answer` orqali serverda tekshiriladi (`AnswerFeedback`). Mock savollarda `correctIndex >= 0` → lokal tekshiruv. Aniqlash UUID-heuristika (`qid.length >= 32`).
5. **Feature flag:** `kEnableContentLibrary=false` bo'lsa `/contests`, `/contest-start`, `/contest-quiz`, `/ranking` → `/dashboard`ga redirect (router guard, `app_router.dart` L177-195).

## 2. Fayl xaritasi
```
lib/features/contests/
  data/
    models/
      contest_model.dart       # ContestModel (+ageLabel, remainingFormatted getters)
      question_model.dart      # QuestionModel (options[4], correctIndex, timeSeconds)
      quiz_state.dart          # QuizState (lifecycle + score + winnerThreshold 0.80)
    repositories/
      contests_backend_repository.dart   # 5 endpoint + AnswerFeedback + parse + mock fallback
      certificate_repository.dart        # sertifikat fetch (403/404 → null)
    mock_questions.dart        # 10 ta hardcoded UZ savol (offline fallback)
  presentation/
    providers/
      contests_providers.dart  # tab + ro'yxat (FutureProvider ContestBundle)
      quiz_provider.dart       # QuizNotifier (StateNotifier<QuizState>, .family(contest))
    screens/
      contests_screen.dart         # ASOSIY sahifa (tab list)
      contest_start_screen.dart    # 3-qadamli intro (PageView, swipe yo'q)
      contest_quiz_screen.dart     # savol-javob + natija
      certificate_screen.dart      # RepaintBoundary→PNG, share/save
    widgets/
      contest_card.dart        # ro'yxat kartasi (active/finished)
      contests_tabs.dart       # Aktiv / Yakunlangan tab'lar
```
Router: `lib/core/routing/app_router.dart` (L177-195 guard, L322/334/341 route'lar).

## 3. Data oqimi
```
Backend (NestJS /content/olympiads)
   → ContestsBackendRepository (Dio, parse, mock fallback)
   → contests_providers (backendContestsProvider: FutureProvider<ContestBundle>)
   → ContestsScreen (Aktiv/Yakunlangan tab) → ContestCard
   → tap → /contest-start → /contest-quiz
   → quizProvider.family(contest) → QuizNotifier
        - savollar: backend detail yoki MockQuestions
        - har javob: POST .../answer → AnswerFeedback (server canonical score)
        - finish: POST .../submit + XP award
```

## 4. Data modellar
**ContestModel:** `id, title, description, soha(predmet), deadline, isActive, bonus(XP), savollarSoni, vaqtChegarasiDaq, minAge?, maxAge?, imageUrl(odatda bo'sh→placeholder), ishtirokchilarSoni`. Getterlar: `ageLabel` ("7-12 yosh"), `remainingFormatted` ("Tugadi"/kun/soat), `placeholderColor/Icon`.

**QuestionModel:** `id, text, options[4], correctIndex(-1=backend mode), explanation?, timeSeconds(40), bonus(50)`.

**QuizState:** lifecycle `loading → intro → playing/paused → finished`; `totalScore, correctCount, wrongCount, currentStreak, maxStreak, currentIndex, effectiveQuestions, attemptId`. **`winnerThreshold = 0.80`** + `isWinner` getter.

## 5. Backend kontrakt (Sprint 5.7c/5.7e)
| Method | Endpoint | Vazifa |
|---|---|---|
| GET | `/content/olympiads` | ro'yxat (active + finished) |
| GET | `/content/olympiads/:id` | detal + savollar |
| POST | `/content/olympiads/:id/start` | attempt yaratish → `attemptId` |
| POST | `/content/olympiads/attempts/:id/answer` | **har savol validatsiyasi** → `AnswerFeedback` |
| POST | `/content/olympiads/attempts/:id/submit` | yakuniy submit (timing) |

**AnswerFeedback:** `isCorrect, correctIndex(canonical), points, scoreSoFar(canonical), correctAnswers, questionsAnswered, questionsTotal, isLastQuestion, attemptFinished, timeExpired`.
HTTP **408**=vaqt tugadi (auto-finish), **409**=takroriy javob (auto-finish). Auth: Bearer token (DioClient RefreshInterceptor `/auth/refresh`/`/auth/child-pair`ni o'tkazib yuboradi).

## 6. Provayderlar
- `contestsActiveTabProvider` — 0=Aktiv, 1=Yakunlangan (StateProvider).
- `backendContestsProvider` — `FutureProvider<ContestBundle>` (active/finished ro'yxatlar).
- `activeContestsProvider` / `finishedContestsProvider` — bundle'dan derived.
- `quizProvider` — `StateNotifierProvider.family(contest)` → **QuizNotifier**:
  `_start()` → `startPlaying()` (+30 XP/+5 DON `contestJoined`) → `selectAnswer()` → `_finish()` (`_submitBackendAttempt()` + `_awardWinnerXp()` agar `isWinner`). Timerlar: `_questionTimer`(40s), `_totalTimer`, `_feedbackTimer`(1.5s).

## 7. Navigatsiya
- Kirish: **bottom-nav** → `/contests`; konkurs **push** bildirishnomasi → `/contests`.
- `ContestCard` tap → `context.push('/contest-start', extra: contest)`.
- Start "Boshlash" → `context.pushReplacement('/contest-quiz', extra: contest)`.
- Quiz finish → `context.go('/contests')`. Sertifikat → `/certificate`. Reyting → `/ranking`.
- **Yakunlangan** karta tap → navigatsiya emas, SnackBar "Natijalari tez orada".

## 8. UI ekranlar (holatlar)
- **ContestsScreen:** header "Konkurslar" + "Reyting" link; Aktiv/Yakunlangan tab; loading=spinner, error=`wifi_off`+retry, empty=ikon+matn. `ListView` bottom padding 140 (nav uchun), `extendBody:true`.
- **ContestCard:** rasm yoki gradient placeholder; subject badge (rang `.withOpacity(0.15)`); star+bonus (aqua); active=stats row (ishtirokchi/yosh/deadline); finished="Yakunlandi" blok.
- **ContestStartScreen:** `PageView` (NeverScrollable — faqat tugma); 1-Info, 2-Rules(5 karta), 3-Ready (pulsing trophy + countdown 3..2..1).
- **ContestQuizScreen:** loading/intro/playing(savol+4 tugma+timer+progress)/finished(ball %, trophy, "G'olib!", stats); confetti streak 3/6/9 va final >80%; ovoz+haptik.
- **CertificateScreen:** `RepaintBoundary.toImage(pixelRatio:3)` → PNG; share/save; bola **nick** (PII — backend maskalashi kerak); 403/404→bo'sh holat (sabab ko'rsatmaydi).

## 9. Styling holati (REDIZAYN UCHUN ASOSIY)
- **Hozir:** global `AppColors` — `primary=#16B5C9 (aqua)`, hover `#0E7490`, disabled `#8FCBD6`. Subject paletта: Matematika→catIndigo, Ona tili→catPink, Ingliz→catTeal, Fizika→catPurple, Kimyo→warning, IT→catEmerald.
- **Light-only:** quiz/start/card'da **night-mode adaptive yo'q** — `AppColors.bgPrimaryDark/...` tokenlar mavjud lekin **ishlatilmaydi**. `context.adaptive.*` ham deyarli yo'q.
- **Parvoz night (`parvozBg #0B1C30`, `parvozGreen=#22D3EE`) — DEFINED, lekin contests'da QO'LLANMAGAN.**
- ⇒ **Redizayn ishi:** 4 ekran + 1 widget'ni Parvoz night aqua dizayniga o'tkazish. Dashboard/notifications/profil kabi **lokal `_P` palitra** (`_P(this.dark)` + `context.adaptive.isDark`) patternidan foydalan. Hozir shartli branch yo'q → qo'lda.

## 10. XP / gamifikatsiya
- `contestJoined`: **+30 XP, +5 DON** (`startPlaying()` paytida).
- `contestWon`: accuracy `>= 0.80` (`QuizState.isWinner`).
- **Dedup:** `_joinedXpAwarded`/`_winnerXpAwarded` bayroqlar + XpService'da `relatedId: contest.id` → bir konkursga bir marta.
- ⚠️ Pairing shart: `parentUid`/`childId` null bo'lsa XP **jimgina** 0 (xato ko'rsatmaydi).

## 11. KRITIK gotcha'lar (redizayn/refactorda asrab qol)
1. **`'/10'` hardcoded** — `_QuestionTopBar` (~L569) progress `(currentIndex+1)/10`, intro "10 ta savol". Backend 5-50 savol qaytarishi mumkin → **`state.effectiveQuestions.length` ishlat**. (Mavjud bug.)
2. **winnerThreshold 0.80** — 3 joyda (UI/XP/sertifikat). O'zgartirsang uchalasini + backendni.
3. **correctIndex=-1 ⇄ UUID-heuristika** (`qid.length>=32`). Backend non-UUID id qaytarsa lokal check ishlaydi → canonical score bypass.
4. **attemptId null** (start fail) → mock rejimga tushadi, score noto'g'ri, sertifikat yashirin — **ogohlantirish yo'q**.
5. **submitBackendAttempt() unawaited** — bola "back" bossa submit chala qolishi mumkin (race).
6. **Network fail har javobda** → `null` → "noto'g'ri" deb hisoblanadi, javob yo'qoladi (retry yo'q).
7. **Quiz state reset yo'q** — `quit()` faqat timerlarni bekor qiladi; provayder invalidatsiya qilinmasa eski state qayta ishlatiladi. Qayta kirishda `ref.invalidate(quizProvider(contest))` kerak bo'lishi mumkin.
8. **`_feedbackTimer`** — har javobdan oldin cancel qilinishi shart (eski `??=` Q2'da osib qo'ygan edi).
9. **Sertifikat 403/404** — `null`, log yo'q → "low score" va "network fail" farqlanmaydi.
10. **Feature flag** `kEnableContentLibrary` — o'chiq bo'lsa deep-link'lar `/dashboard`ga ketadi (test qilganda yoq).
11. Confetti/streak ranglari category palitrasidan (pink/lavender/orange/mint) — aqua motivga **harmonize** qilish kerak bo'lishi mumkin.

## 12. Agar REDIZAYN qilsang — tavsiya
- **Tegma (logikani saqlash):** `quiz_provider.dart`, `quiz_state.dart`, `contests_backend_repository.dart`, `question_model.dart`, XP/dedup, timer/feedback mantiq. Faqat **UI/rang** o'zgarsin.
- **O'zgartir:** `contests_screen`, `contest_card`, `contests_tabs`, `contest_start_screen`, `contest_quiz_screen`, `certificate_screen` — lokal `_P` aqua/night palitra + glass/solid kartalar (dashboard patterni).
- **Bonus tuzatish:** `'/10'` → `effectiveQuestions.length` (mavjud bug, redizayn bilan birga).
- **Tekshir:** `flutter analyze lib/features/contests` = 0 xato; mock rejim (internetsiz) + real rejim; feature flag yoq/yoniq.
