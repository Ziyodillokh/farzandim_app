# Parvoz dizayn-tizimi — Farzandim Ota-ona ilovasi

> Bu hujjat yangi **"Parvoz"** dizayn tilini hujjatlashtiradi. Maqsad: boshqa
> AI yoki dasturchi ham **qaysi tugma primary, qaysi secondary**, kartalar
> qanday qurilishi, ranglar/shriftlar — hammasini tushunib, izchil davom
> ettira olsin. (Oxirgi yangilanish: 2026-06.)

## Migration konteksti
Ilova eski **"Deep Sea"** temadan (teal/yashil + Inter, `AppColors`/
`AppTextStyles`) yangi **"Parvoz"** temaga (chuqur qora-ko'k + ko'k aksent +
Unbounded/Poppins + shisha) **bosqichma-bosqich** ko'chmoqda.

- ✅ Ko'chirilgan: Onboarding (til tanlash, welcome, login, register) + **Dashboard**.
- ⏳ Hali eski teal temada: settings, location, app-limits, schedules, weekly-report va boshqa ichki ekranlar.

Yangi ekran qilganda — **Parvoz** tilida qil (quyidagi qoidalar).

---

## 1. Ranglar
| Token | HEX / alpha | Ishlatilishi |
|---|---|---|
| Fon (bg) | `#00060A` (dashboard) / `#02060D` (onboarding) | Ekran foni — deyarli qora-ko'k |
| **Primary (ko'k)** | `#216BFF` | Primary tugma fill, aktiv element, fokus rim, badge |
| blueLight | `#3C82FF` | Gradient yuqori rang, sheen |
| glow | `#508AFF` | Ko'k yog'du (radial) |
| Card fon | oq @ **7%** (`0x12FFFFFF`) | Flat karta foni |
| Card border | oq @ **10%** (`0x1AFFFFFF`) | Karta/tugma chegarasi |
| Matn | `#FFFFFF` | Asosiy matn |
| Matn dim | oq @ **55%** (`0x8CFFFFFF`) | Ikkilamchi/izoh matn |
| Hint | oq @ 35% | Input placeholder |
| Online | `#87FF46` | Telegram uslubidagi yashil online nuqta |
| Status | yashil=online, sariq=aloqa uzildi, kulrang=offline, qizil=xato | |

Onboarding tokenlari: `ParvozColors` (`lib/shared/widgets/parvoz_ui.dart`):
`bg #02060D`, `blue #216BFF`, `blueLight #3C82FF`, `glow #508AFF`.

> ⚠️ Teal/lime ranglardan QOCH. Aksent FAQAT ko'k. `AppColors` (teal) yangi
> Parvoz ekranlarda ishlatilmaydi.

## 2. Shriftlar
- **Unbounded** — sarlavhalar, katta raqamlar, brend (w600–w700). `GoogleFonts.unbounded`.
- **Poppins** — body, label, tugma, izoh (w400–w600). `GoogleFonts.poppins`.
- Inter ISHLATILMAYDI (eski tema).

## 3. Tugmalar — ASOSIY QOIDA
- **PRIMARY = KO'K.** To'ldirilgan ko'k pill (`#3C82FF → #216BFF` diagonal
  gradient) + oq matn + ko'k glow soya. Asosiy harakat uchun (Kirish,
  Ro'yxatdan o'tish, Kod yuborish, Tasdiqlash).
  → `ParvozPrimaryButton` (`parvoz_ui.dart`, ichida `ParvozGlass(blue: true)`).
- **SECONDARY = SHISHA.** Frosted glass pill. Ikkilamchi harakat uchun
  (Apple/Google, "Kirish" welcome'da, bola almashtirish, bola qo'shish,
  sozlamalar, orqaga).
  → `ParvozSecondaryButton` (`blue: false`); dashboard'da `_Glass`
  (`dashboard_sections.dart`).
- **Shisha "retsepti"** (har doim shu 5 qatlam): translucent fill gradient +
  sheen (yumshoq yorug'lik) + tepa specular chiziq (~1.5px) + yorqin rim
  border (1.2px, oq ~20%) + chuqurlik soyasi (qora) + `BackdropFilter` blur ~10.
- Geometriya: hamma tugma **PILL** (radius 999), balandlik 54–56.

## 4. Inputlar
`ParvozTextField` (`parvoz_ui.dart`): shisha pill input, yorliq tepada,
fokusda **ko'k rim**, parolda ko'z toggle, placeholder oq@35%.
- Kursor/matn belgilash **KO'K** — `TextSelectionTheme` override bilan (global
  teal'ni bostiradi).
- Global `InputDecorationTheme` teal fill/border'lari `filled: false` + barcha
  `*Border: InputBorder.none` bilan o'chiriladi (faqat tashqi DecoratedBox rim
  qoladi).

## 5. Kartalar
- Dashboard kartalari = **FLAT shisha**: `_Card` (`dashboard_sections.dart`) —
  oq 7% fon + oq 10% border + radius 24. (Onboarding'dagi og'ir teal `GlassCard`
  EMAS.)
- Onboarding hero kartalar (eski teal `GlassCard`) — Parvoz ekranlarda
  ishlatilmaydi.

---

## 6. DASHBOARD tuzilmasi (bo'lim → real ma'lumot manbai)
Fayl: `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
(+ part `dashboard_sections.dart`). Holatlar: loading / error / empty / body.
Tanlangan bola: `selectedChildIndexProvider` + `childrenListProvider`.

| Bo'lim (widget) | Nima ko'rsatadi | Ma'lumot manbai / harakat |
|---|---|---|
| Header (`_Header`) | Markaziy avatar (qora dumaloq border #1A1F26 ustida) + online yashil nuqta + ism + qurilma/batareya. Orqada nozik ko'k yog'du + jinsga qarab tarqoq ikonalar (qiz=kapalak, o'g'il=mototsikl) | `ChildAvatar`, `child.isLiveOnline`, `child.deviceModel`, `child.deviceInfo.batteryLevel`, `child.gender` |
| — Messenger (chap-tepa) | `ic_chat.svg` | → `qaVoicePath(childId)` |
| — Bildirishnoma (o'ng-tepa) | `ic_bell.svg` + o'qilmagan qizil nuqta | `unreadCountProvider` → `notifications` |
| Location (`_LocationCard`) | Geo-zona nomi / ko'cha / koordinata / "Ko'chada" | `childPlaceProvider(childId)` → `locationPath` |
| Ekran vaqti (`_ScreenTimeCard`) | Bugungi jami vaqt + top 3 ilova | `todayScreenTimeMsProvider`, `todayUsageProvider.filteredApps` |
| XP balansi (`_XpCard`) | Bola XP + reyting (atrofidagi 3 qator; joriy bola o'z avatari, ko'k) | `childProfileProvider.xp`, `leaderboardProvider` → `childAchievementsPath` |
| Kun tartibi (`_ScheduleCard`) | "Tez kunda" (jadval ishlanmoqda) | — |
| Ilova cheklovlari (`_ActionCard`) | `ic_restrict.svg` (Solar) | → `appLimitsPath` |
| Hisobotlar (`_ActionCard`) | `ic_report.svg` (Solar) | → `weeklyReportPath` |
| Bola qo'shish (`_AddChildButton`) | Shisha pill (`_Glass`) | → `addChild` |
| Pastki bar (`_BottomBar`) | Bolalar almashtirgich (shisha pill; faol bola avatar+ism marquee) + "+" (bola<3) + sozlamalar (shisha dumaloq) | `selectedChildIndexProvider` / `addChild` / `settings` |

### Location card logikasi (`child_place_provider.dart`)
`childPlaceProvider(childId)` → `({String? zoneName, String? street})`:
1. `childLocationProvider` null → "Ko'chada" (UI default).
2. `geoZonesProvider` — radius ichidagi eng yaqin zona bo'lsa → `zoneName`.
3. Aks holda `childAddressProvider` (reverse geocode) → ko'cha.
4. Topilmasa → koordinata. (Masofa: Haversine.)

## 7. Maxsus komponentlar
- `_MarqueeText` — uzun ism `maxWidth`'dan oshsa chap tomonga silliq suriladi.
- `ChildAvatar` (shared) — faqat rasm/sticker; online nuqta YO'Q (Stack bilan qo'shiladi).
- Maks **3 bola** (`_kMaxChildren`).

## 8. Asosiy fayllar
- Dizayn-tizim: `lib/shared/widgets/parvoz_ui.dart`
- Dashboard: `lib/features/dashboard/presentation/screens/dashboard_screen.dart` + `dashboard_sections.dart`
- Location logika: `lib/features/location/presentation/providers/child_place_provider.dart`
- Asset ikonalar (`assets/icons/`): `parvoz_logo_mark`, `flag_uz/ru/gb`, `ic_apple_mark`, `ic_google_mark`, `ic_chat`, `ic_bell`, `ic_restrict`, `ic_report`, `scatter_moto`, `scatter_butterfly`
- Fon rasm: `assets/images/welcome_bg_parvoz.jpg`

## 9. Yangi ekran qilganda (CHECKLIST)
1. Fon `#00060A`/`#02060D`. Shrift Unbounded (sarlavha) + Poppins (body).
2. Aksent FAQAT ko'k `#216BFF` (teal/lime YO'Q).
3. Primary harakat → ko'k tugma; ikkilamchi → shisha.
4. Kartalar → flat `_Card` uslubi (oq 7% + border + radius 24).
5. Matn belgilash/kursor → ko'k.
6. Real ma'lumot: mavjud provayderlarni ishlat (`childrenProvider`,
   `childProfileProvider`, `todayUsageProvider`, `childLocationProvider`,
   `geoZonesProvider`, `leaderboardProvider`, `unreadCountProvider`, ...).
7. `flutter analyze --fatal-infos` = 0 (CI darvozasi). Lint qoidalari:
   very_good_analysis (matn ≤80 belgi, trailing comma, const, va h.k.).
