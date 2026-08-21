// "Tariflar" — obuna (paywall) sahifasi. Tizim sozlamalari sahifasidagi
// premium banner "Batafsil" tugmasidan ochiladi.
//
// Dizayn (Figma) 1:1: ko'k→qora diagonal fon + tepadan tushuvchi nur
// (god-ray), "+1k obunachi" badge, "Tariflar" sarlavha va 3 ta tarif kartasi:
//   • Start   — Tekin (shisha karta, tugmasiz)
//   • Standart — $5/oy (ko'k karta, oq "Standart ulanish" tugma)
//   • Premium  — $10/oy (to'q karta, ko'k "Premiumga ulanish" tugma)
//
// Eslatma: hozircha xarid tizimi (in-app purchase) ulanmagan — ulanish
// tugmalari "tez kunda" toast ko'rsatadi. Real to'lov keyin ulanadi.

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/settings/data/apple_iap_service.dart';
import 'package:farzandim/features/settings/data/entitlement.dart';
import 'package:farzandim/features/settings/data/repositories/backend_payments_repository.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:url_launcher/url_launcher.dart';

// ════════════ Tokenlar (lokal) ════════════
const _bg = Color(0xFF00060A);
const _bgTop = Color(0xFF034470); // fon gradient tepasi (chuqur ko'k)
const _blue = Color(0xFF216BFF); // brend ko'k (badge, ko'k karta, CTA)
const _rayCore = Color(0xFF1859FF); // nur o'zagi
const _rayHalo = Color(0xFF5D8BFF); // nur halosi
const _icon = Color(0xFFF9F9F9); // ikon/near-white (yopish tugmasi)
const _ctaDark = Color(0xFF0A1B30); // oq tugmadagi to'q matn (Standart)

TextStyle _unb(
  double size, {
  FontWeight w = FontWeight.w600,
  Color c = Colors.white,
  double ls = -0.5,
}) => GoogleFonts.unbounded(
  fontSize: size,
  fontWeight: w,
  color: c,
  letterSpacing: ls,
  height: 1.3,
);

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.5);

/// Funksiya kalitini o'qiladigan nomga aylantiradi. Tarjima topilsa — o'sha;
/// topilmasa kalitni "humanize" qiladi ("full_access" → "Full access"), shunda
/// xom `planFeatures.xxx` hech qachon ekranda ko'rinmaydi (admin erkin kalit
/// yozgan bo'lsa ham).
String _featureLabel(String key) {
  final path = 'planFeatures.$key';
  final t = path.tr();
  if (t != path) return t;
  final cleaned = key.replaceAll('_', ' ').trim();
  if (cleaned.isEmpty) return key;
  return cleaned[0].toUpperCase() + cleaned.substring(1);
}

/// Tarif kartasi ko'rinishi.
enum _PlanStyle { glass, blue, dark }

/// Tariflar (paywall) ekrani — HAQIQIY tariflar backend'dan, "Ulanish"
/// tugmasi Click yoki Payme to'lov sahifasini ochadi (ikkalasi ham mavjud
/// bo'lsa — avval to'lov usuli tanlanadi).
class ParvozPremiumScreen extends ConsumerStatefulWidget {
  /// `ParvozPremiumScreen` konstruktor.
  const ParvozPremiumScreen({super.key});

  @override
  ConsumerState<ParvozPremiumScreen> createState() =>
      _ParvozPremiumScreenState();
}

class _ParvozPremiumScreenState extends ConsumerState<ParvozPremiumScreen>
    with WidgetsBindingObserver {
  /// Hozir checkout ochilayotgan tarif id (tugmada spinner). `null` — bo'sh.
  /// Restore paytida `'_restore'` bo'ladi.
  String? _busyPlanId;

  /// `true` — yillik ko'rinish (narx = oylik×10, 2 oy tekin). `false` — oylik.
  bool _yearly = false;

  /// iOS StoreKit — obuna FAQAT Apple IAP orqali (App Store 3.1.1). Android
  /// va web'da ishlatilmaydi (u yerda Click checkout).
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _iapSub;

  /// iOS bo'lsa Apple IAP. web guard (Platform web'da throw qiladi).
  bool get _isApple => !kIsWeb && Platform.isIOS;

  /// ⚠️ ANDROID'DA TASHQI TO'LOVNI KO'RSATISH — Play siyosati kaliti.
  ///
  /// Google Play Payments siyosati: ilova ichida foydalanuvchini Play
  /// Billing'dan BOSHQA to'lov usuliga YETAKLASH taqiqlangan ("developers
  /// may not lead users to a payment method other than Google Play's
  /// billing system"). Istisno faqat
  /// AQSh (sud qarori), YeIH (DMA), Hindiston va Janubiy Koreya uchun —
  /// O'zbekiston bu ro'yxatda YO'Q.
  ///
  /// 2026-08-19: `true` — EGA QARORI bilan tashqi Click checkout QAYTARILDI.
  ///
  /// Qaror konteksti (kelajakdagi o'zim/boshqa dasturchi uchun):
  ///   • Play Billing texnik jihatdan ochiq (O'zbekiston merchant sifatida
  ///     qo'llab-quvvatlanadi, obunadan 15%), LEKIN Google Play O'zbekistonda
  ///     faqat Visa/Mastercard/Amex/Discover qabul qiladi — UzCard va Humo
  ///     ISHLAMAYDI. Mijozlarning aksariyati aynan shu ikki kartada, ya'ni
  ///     Play Billing'ga o'tish daromadning katta qismini yo'qotardi.
  ///   • Tashqi to'lov Google siyosati bo'yicha faqat AQShda ruxsat etilgan
  ///     (2025-okt, Epic sudi). O'zbekiston uchun eski qoida kuchida — ya'ni
  ///     bu bayroq `true` bo'lishi Payments siyosati buzilishi HISOBLANADI.
  ///     Xavf ega tomonidan ochiq baholanib qabul qilingan.
  ///
  /// `true` holatda Android'da narx, "Ulanish" tugmasi va oylik/yillik
  /// almashtirgich ko'rinadi va Click checkout ochiladi (web bilan bir xil).
  /// Qayta o'chirish kerak bo'lsa — shu qiymatni `false` qilish KIFOYA,
  /// boshqa joyga tegish shart emas (UI to'liq shu bayroqqa bo'ysunadi).
  static const bool kAndroidExternalCheckoutEnabled = true;

  /// Android'da sotib olish yuzasi (narx + tugma + checkout) ko'rsatiladimi.
  bool get _androidPurchaseVisible =>
      kIsWeb || _isApple || kAndroidExternalCheckoutEnabled;

  /// iOS: StoreKit'dan yuklangan mahsulot narxlari (productId -> tafsilot).
  /// Kartadagi narx StoreKit bilan MOS bo'lishi shart — aks holda
  /// foydalanuvchi "29 000 so'm" ko'radi-yu, xarid bosilganda Apple tizim
  /// oynasi "$2.99" ko'rsatadi (ikki xil narx = Apple Review rad sababi).
  final Map<String, ProductDetails> _appleProducts = {};
  bool _appleProductsLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_isApple) {
      // StoreKit xarid/restore natijalari SHU stream'dan keladi.
      _iapSub = _iap.purchaseStream.listen(
        _onPurchaseUpdates,
        onError: (Object _) {
          if (mounted) setState(() => _busyPlanId = null);
        },
      );
      unawaited(_loadAppleProducts());
    }
  }

  /// StoreKit narxlarini oldindan yuklaydi (Apple App Store Connect'dagi
  /// haqiqiy, mahalliy valyutada formatlangan narx) — [_priceLabel] shundan
  /// foydalanadi, backend UZS narxi EMAS.
  Future<void> _loadAppleProducts() async {
    try {
      if (!await _iap.isAvailable()) return;
      final resp = await _iap.queryProductDetails(AppleProductIds.all);
      if (!mounted) return;
      setState(() {
        for (final p in resp.productDetails) {
          _appleProducts[p.id] = p;
        }
        _appleProductsLoaded = true;
      });
    } catch (_) {
      // Jim — StoreKit narxi bo'lmasa _priceLabel "—" ko'rsatadi (so'm
      // FALLBACK QILINMAYDI, aks holda yana nomuvofiqlik yuzaga keladi).
    }
  }

  @override
  void dispose() {
    _iapSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Click/Payme to'lov sahifasidan qaytilganda tarif + planlarni
    // yangilaymiz — to'lov tasdiqlangan bo'lsa yangi tarif DARHOL kuchga
    // kiradi.
    if (state == AppLifecycleState.resumed) {
      ref
        ..invalidate(entitlementProvider)
        ..invalidate(plansProvider);
    }
  }

  /// Tarifni sotib olish. iOS'da Apple IAP (App Store 3.1.1), boshqa
  /// platformalarda Click/Payme checkout (tashqi to'lov sahifasi).
  Future<void> _subscribe(PlanEntry plan) async {
    if (_busyPlanId != null) return;
    // iOS: raqamli obuna FAQAT Apple IAP orqali. Tashqi Click/Payme to'lovi
    // iOS'da ISHLATILMAYDI (Apple 3.1.1 bo'yicha rad etadi).
    if (_isApple) {
      await _subscribeApple(plan);
      return;
    }
    // Play siyosati kaliti (yuqoridagi `kAndroidExternalCheckoutEnabled`
    // izohiga qarang) — o'chirilgan bo'lsa tashqi checkout CHAQIRILMAYDI.
    if (!_androidPurchaseVisible) return;

    // To'lov usuli: backend qaysi provayderlar sozlanganini aytadi
    // (`availableProviders`). Bittasi bo'lsa — to'g'ridan-to'g'ri; ikkalasi
    // (Click + Payme) bo'lsa — foydalanuvchi tanlaydi. Bo'sh bo'lsa (hech biri
    // sozlanmagan) `click` bilan urinib ko'ramiz — backend 503 → xato toast.
    final providers =
        ref.read(plansProvider).valueOrNull?.externalProviders ??
        const <String>[];
    String provider;
    if (providers.length > 1) {
      final picked = await _PayMethodSheet.show(
        context,
        providers: providers,
        planName: plan.name,
        priceLabel: _priceLabel(plan),
      );
      if (picked == null || !mounted) return; // bekor qildi
      provider = picked;
    } else {
      provider = providers.isNotEmpty ? providers.first : 'click';
    }

    setState(() => _busyPlanId = plan.id);
    try {
      final url = await ref
          .read(backendPaymentsRepositoryProvider)
          .checkout(
            planId: plan.id,
            provider: provider,
            billingPeriod: _yearly ? 'yearly' : 'monthly',
          );
      if (url.isEmpty) throw Exception('empty checkout url');
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) throw Exception('launch failed');
    } catch (_) {
      if (mounted) AppToast.error(context, 'premium.checkoutError'.tr());
    } finally {
      if (mounted) setState(() => _busyPlanId = null);
    }
  }

  /// iOS StoreKit xaridini boshlaydi. Natija `purchaseStream` orqali
  /// [_onPurchaseUpdates]'ga keladi — shuning uchun bu yerda `finally` yo'q
  /// (spinner xarid yakunlangach o'chadi).
  Future<void> _subscribeApple(PlanEntry plan) async {
    final productId = AppleProductIds.forPlan(
      plan.entitlementTier,
      yearly: _yearly,
    );
    if (productId == null) {
      if (mounted) AppToast.error(context, 'premium.iapPlanUnavailable'.tr());
      return;
    }
    setState(() => _busyPlanId = plan.id);
    try {
      // ⚠️ HAR XATO UCHUN ALOHIDA XABAR — ataylab.
      // Ilgari uchala holat ham bitta "To'lov sahifasini ochib bo'lmadi"
      // toastini berardi va sabab NIMA ekanini aniqlab bo'lmasdi (2026-08-21
      // da haqiqiy qurilmada aynan shu vaqt yo'qotdi). Endi foydalanuvchi
      // xabarning o'zidan nima qilish kerakligini biladi.
      if (!await _iap.isAvailable()) {
        // Odatda: Ekran vaqti cheklovi ilova ichidagi xaridlarni o'chirgan,
        // yoki qurilma MDM bilan boshqariladi.
        throw const _IapFailure('premium.iapDeviceBlocked');
      }
      final resp = await _iap.queryProductDetails(<String>{productId});
      if (resp.productDetails.isEmpty) {
        // Mahsulot App Store Connect'da yo'q yoki hali "Ready to Submit"
        // holatiga o'tmagan.
        throw const _IapFailure('premium.iapProductMissing');
      }
      final param = PurchaseParam(productDetails: resp.productDetails.first);
      // Obunalar in_app_purchase'da `buyNonConsumable` orqali sotib olinadi.
      await _iap.buyNonConsumable(purchaseParam: param);
    } on _IapFailure catch (e) {
      if (mounted) {
        AppToast.error(context, e.messageKey.tr());
        setState(() => _busyPlanId = null);
      }
    } catch (e) {
      // Qolgan hamma narsa (StoreKit navbatida tugallanmagan tranzaksiya,
      // sandbox akkaunt muammosi, tarmoq uzilishi...).
      debugPrint('[IAP] xarid xatosi ($productId): $e');
      if (mounted) {
        // ⚠️ VAQTINCHA DIAGNOSTIKA (2026-08-22).
        // Apple'ning XOM xato matnini ekranga chiqaramiz. Sabab: sinov
        // qurilmasi boshqa odamda va Mac'ga ulab Console'dan log o'qish
        // imkoni yo'q, umumiy xabar esa sababni ko'rsatmaydi va bir necha
        // build siklini yo'qotdi.
        //
        // App Store'ga YUBORISHDAN OLDIN OLIB TASHLANSIN — foydalanuvchiga
        // texnik matn ko'rsatish yaxshi tajriba emas. Faqat `'premium.
        // iapFailed'.tr()` qolishi kerak.
        AppToast.error(
          context,
          '${'premium.iapFailed'.tr()}\n\n[$productId]\n$e',
        );
        setState(() => _busyPlanId = null);
      }
    }
  }

  /// "Xaridlarni tiklash" — Apple MAJBURIY qiladi (yangi qurilma / qayta
  /// o'rnatishdan keyin obunani qaytarish). Natija `purchaseStream`'ga keladi.
  Future<void> _restoreApple() async {
    if (_busyPlanId != null) return;
    setState(() => _busyPlanId = '_restore');
    try {
      await _iap.restorePurchases();
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'premium.checkoutError'.tr());
        setState(() => _busyPlanId = null);
      }
    }
  }

  /// StoreKit xarid/restore natijalari: purchased/restored → backend
  /// tekshiruvi → entitlement yangilash; so'ng har tranzaksiya YOPILADI.
  ///
  /// LOAD-BEARING: backend so'rovi va tranzaksiyani yopish alohida
  /// try/finally'larga o'ralgan. Sabab — 2026-08-17 haqiqiy qurilmada
  /// aniqlangan xato: `verifyApplePurchase` tarmoq uzilishida (masalan
  /// parvoz rejimi) throw qilsa, eski kodda bu istisno butun funksiyani
  /// yiqitardi — natijada `completePurchase` HECH QACHON chaqirilmasdi,
  /// tranzaksiya StoreKit navbatida abadiy "osilib" qolardi va u KEYINGI
  /// barcha xaridlarni ham bloklardi ("Не удалось открыть страницу оплаты,
  /// повторите позже"), spinner esa mangu aylanardi (`_busyPlanId`
  /// tozalanmasdi). Endi tranzaksiya har doim yopiladi — backend
  /// tasdiqlamasa ham, StoreKit navbati bo'shaydi; `AppleReceiptSyncService`
  /// keyingi resume'da kvitansiyani qayta yuborib entitlement'ni tuzatadi.
  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    try {
      for (final p in purchases) {
        if (p.status == PurchaseStatus.pending) continue;
        try {
          if (p.status == PurchaseStatus.purchased ||
              p.status == PurchaseStatus.restored) {
            var ok = false;
            try {
              ok = await ref
                  .read(backendPaymentsRepositoryProvider)
                  .verifyApplePurchase(
                    productId: p.productID,
                    verificationData: p.verificationData.serverVerificationData,
                    transactionId: p.purchaseID,
                  );
            } catch (_) {
              // Tarmoq/backend xatosi — tranzaksiya baribir pastda
              // YOPILADI. AppleReceiptSyncService keyingi resume'da qayta
              // urinadi (kvitansiya StoreKit'da mahalliy saqlanib qoladi).
              ok = false;
            }
            if (mounted) {
              if (ok) {
                ref
                  ..invalidate(entitlementProvider)
                  ..invalidate(plansProvider);
                AppToast.success(context, 'premium.subscribed'.tr());
              } else {
                AppToast.error(context, 'premium.checkoutError'.tr());
              }
            }
          } else if (p.status == PurchaseStatus.error) {
            if (mounted) AppToast.error(context, 'premium.checkoutError'.tr());
          } else if (p.status == PurchaseStatus.canceled) {
            // Foydalanuvchi StoreKit oynasida o'zi bekor qilgan — bu XATO
            // EMAS, shuning uchun toast ko'rsatmaymiz (jim).
          }
        } finally {
          // Apple: har yakunlangan tranzaksiyani YOPISH shart — status yoki
          // yuqoridagi xatolardan qat'i nazar, aks holda StoreKit navbati
          // bloklanib qoladi.
          if (p.pendingCompletePurchase) {
            await _iap.completePurchase(p);
          }
        }
      }
    } finally {
      if (mounted) setState(() => _busyPlanId = null);
    }
  }

  /// Tarif uslubi tier bo'yicha: free -> glass, standard -> blue, aks -> dark.
  _PlanStyle _styleFor(PlanEntry p) {
    if (p.isFree) return _PlanStyle.glass;
    if (p.entitlementTier == 'premium') return _PlanStyle.dark;
    return _PlanStyle.blue;
  }

  /// "29 000 so'm/oy" ko'rinishidagi narx (Android/web — backend UZS).
  /// iOS'da esa StoreKit'ning HAQIQIY narxi ("$2.99/oy" kabi) — bu xarid
  /// bosilganda Apple tizim oynasida ko'rinadigan narx bilan AYNAN mos
  /// bo'lishi shart. Bepul bo'lsa i18n "Tekin". Android/web'da yillik narx =
  /// oylik × 10 (2 oy tekin); iOS'da yillik narx App Store Connect'da
  /// mustaqil belgilangan (StoreKit'dan to'g'ridan-to'g'ri keladi).
  String _priceLabel(PlanEntry p) {
    if (p.isFree) return 'premium.startPrice'.tr();
    if (_isApple) {
      final productId = AppleProductIds.forPlan(
        p.entitlementTier,
        yearly: _yearly,
      );
      final product = productId != null ? _appleProducts[productId] : null;
      if (product != null) {
        final suffix = _yearly
            ? '/${'premium.perYear'.tr()}'
            : '/${'premium.perMonth'.tr()}';
        return '${product.price}$suffix';
      }
      // StoreKit narxi hali yuklanmagan/topilmadi — backend UZS'ga FALLBACK
      // QILINMAYDI (bu yana nomuvofiqlikka olib keladi). Yuklanish holatida
      // "···", umuman topilmasa "—".
      return _appleProductsLoaded ? '—' : '···';
    }
    final amount = _yearly ? p.priceUzs * 10 : p.priceUzs;
    final s = amount.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    final suffix = _yearly
        ? '/${'premium.perYear'.tr()}'
        : '/${'premium.perMonth'.tr()}';
    return "$b ${'premium.sum'.tr()}$suffix";
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(plansProvider);
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const Positioned.fill(child: _Background()),
          SafeArea(
            child: Column(
              children: [
                // Tepa qator — o'ngda yopish (x) tugmasi.
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _CloseButton(
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    child: Column(
                      children: [
                        const Center(child: _SubscribersBadge()),
                        const SizedBox(height: 14),
                        Text(
                          'premium.title'.tr(),
                          textAlign: TextAlign.center,
                          style: _unb(32, ls: -1),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'premium.subtitle'.tr(),
                          textAlign: TextAlign.center,
                          style: _pop(
                            14,
                            c: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const _CurrentPlanLabel(),
                        const SizedBox(height: 16),
                        // Xarid yashirilganda oylik/yillik almashtirgich ham
                        // yashirinadi — narxsiz ekranda u ma'nosiz va
                        // "to'lovga undash" taassurotini beradi (Play
                        // Payments siyosati, kAndroidExternalCheckoutEnabled
                        // izohiga qarang).
                        if (_androidPurchaseVisible) ...[
                          _BillingToggle(
                            yearly: _yearly,
                            onChanged: (v) => setState(() => _yearly = v),
                          ),
                          const SizedBox(height: 24),
                        ] else
                          const SizedBox(height: 8),
                        plansAsync.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.only(top: 40),
                            child: CircularProgressIndicator(color: _blue),
                          ),
                          error: (_, __) => Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: Text(
                              'premium.loadError'.tr(),
                              textAlign: TextAlign.center,
                              style: _pop(
                                14,
                                c: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                          data: (res) => Column(
                            children: [
                              _PlansList(
                                plans: res.plans,
                                busyPlanId: _busyPlanId,
                                styleFor: _styleFor,
                                priceLabel: _priceLabel,
                                onSubscribe: _subscribe,
                                purchaseVisible: _androidPurchaseVisible,
                              ),
                              // Apple MAJBURIY: restore (faqat iOS).
                              if (_isApple) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _busyPlanId != null
                                      ? null
                                      : _restoreApple,
                                  child: _busyPlanId == '_restore'
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: _blue,
                                          ),
                                        )
                                      : Text(
                                          'premium.restore'.tr(),
                                          style: _pop(
                                            13,
                                            c: Colors.white.withValues(
                                              alpha: 0.7,
                                            ),
                                          ),
                                        ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tariflar ro'yxati — har biri `_PlanCard` (dizayn saqlanadi).
/// Apple IAP oqimidagi KUTILGAN xatolar — foydalanuvchiga ko'rsatiladigan
/// tarjima kaliti bilan birga tashiladi.
///
/// Oddiy `Exception` o'rniga shu ishlatiladi, chunki `catch (_)` bilan hamma
/// narsani bir xil xabarga aylantirish sababni yashiradi va nosozlikni
/// qurilmada topib bo'lmay qoladi.
class _IapFailure implements Exception {
  const _IapFailure(this.messageKey);

  /// `premium.*` tarjima kaliti.
  final String messageKey;

  @override
  String toString() => '_IapFailure($messageKey)';
}

class _PlansList extends StatelessWidget {
  const _PlansList({
    required this.plans,
    required this.busyPlanId,
    required this.styleFor,
    required this.priceLabel,
    required this.onSubscribe,
    required this.purchaseVisible,
  });

  final List<PlanEntry> plans;
  final String? busyPlanId;
  final _PlanStyle Function(PlanEntry) styleFor;
  final String Function(PlanEntry) priceLabel;
  final Future<void> Function(PlanEntry) onSubscribe;

  /// `false` (Android, tashqi checkout o'chiq) — pullik kartalarda narx va
  /// "Ulanish" tugmasi KO'RSATILMAYDI; tariflar faqat imkoniyatlar ro'yxati
  /// bo'lib qoladi. Play Payments siyosati: tashqi to'lovga yetaklovchi
  /// narx/CTA ko'rsatishning o'zi ham "leading users to a payment method
  /// other than Google Play's billing" hisoblanadi.
  final bool purchaseVisible;

  /// Tarif darajasi tartibi — delta ("pastki tarifdagi hammasi +") hisoblash
  /// uchun har tarifning bir pastki tarifini topishda ishlatiladi.
  static int _rank(String tier) => switch (tier) {
    'free' => 0,
    'basic' => 1,
    'standard' => 2,
    'premium' => 3,
    'vip' => 4,
    _ => 5,
  };

  @override
  Widget build(BuildContext context) {
    // Daraja bo'yicha tartiblaymiz — har tarifning bir pastki tarifi kerak.
    final sorted = [...plans]
      ..sort(
        (a, b) => _rank(a.entitlementTier).compareTo(_rank(b.entitlementTier)),
      );
    return Column(
      children: [
        for (var i = 0; i < sorted.length; i++) ...[
          if (i != 0) const SizedBox(height: 16),
          _buildCard(sorted, i),
        ],
      ],
    );
  }

  Widget _buildCard(List<PlanEntry> sorted, int i) {
    final plan = sorted[i];
    // Bir pastki tarif (bo'lsa) — uning funksiyalarini qayta yozmaymiz, faqat
    // "X tarifidagi barchasi" + shu tarifning QO'SHIMCHA funksiyalari.
    final lower = i > 0 ? sorted[i - 1] : null;
    String? includesLabel;
    var shownFeatures = plan.features;
    if (lower != null) {
      final lowerSet = lower.features.toSet();
      shownFeatures = [
        for (final f in plan.features)
          if (!lowerSet.contains(f)) f,
      ];
      includesLabel = 'plans.everythingIn'.tr(namedArgs: {'plan': lower.name});
    }
    // Xarid yashirilgan rejimda pullik tarifda narx ham, tugma ham yo'q —
    // bo'sh narx `_PlanCard`da qator sifatida chizilmaydi.
    final purchasable = !plan.isFree && purchaseVisible;
    return _PlanCard(
      name: plan.name,
      price: plan.isFree || purchaseVisible ? priceLabel(plan) : '',
      style: styleFor(plan),
      includesLabel: includesLabel,
      features: shownFeatures,
      // Bepul tarifda tugma yo'q (obuna talab qilmaydi).
      ctaLabel: purchasable ? 'premium.subscribeCta'.tr() : null,
      loading: busyPlanId == plan.id,
      onCta: purchasable ? () => onSubscribe(plan) : null,
    );
  }
}

// ════════════ Tarif kartasi ════════════
// Dastlab faqat bir nechta qator ("_collapsedCount") + "Batafsil" tugmasi
// ko'rinadi. "Batafsil" bosilsa hamma imkoniyatlar ochiladi va tugma
// "Ulanish"ga aylanadi (bepul tarifda — "Yig'ish").
class _PlanCard extends StatefulWidget {
  const _PlanCard({
    required this.name,
    required this.price,
    required this.style,
    required this.features,
    this.includesLabel,
    this.ctaLabel,
    this.onCta,
    this.loading = false,
  });

  final String name;
  final String price;
  final _PlanStyle style;

  /// "X tarifidagi barchasi" qatori (pastki tarif bo'lsa) — barcha funksiyani
  /// qayta yozmaslik uchun. `null` bo'lsa ko'rsatilmaydi (eng past tarif).
  final String? includesLabel;

  /// Shu tarifning QO'SHIMCHA funksiya kalitlari (delta) — checkmark bilan.
  final List<String> features;
  final String? ctaLabel;
  final VoidCallback? onCta;
  final bool loading;

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  /// Yig'ilgan holatda ko'rinadigan qatorlar soni (includesLabel + funksiya).
  static const _collapsedCount = 4;
  bool _expanded = false;

  /// Qatorlarni ajratgich chiziq bilan quradi.
  List<Widget> _featureRows(
    List<({String label, bool emphasize})> items,
    Color featureColor,
    Color dividerColor,
  ) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      rows.add(
        _PlanFeature(
          label: items[i].label,
          color: featureColor,
          emphasize: items[i].emphasize,
        ),
      );
      if (i != items.length - 1) {
        rows
          ..add(const SizedBox(height: 12))
          ..add(Divider(height: 1, thickness: 1, color: dividerColor))
          ..add(const SizedBox(height: 12));
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final blue = w.style == _PlanStyle.blue;
    final featureColor = switch (w.style) {
      _PlanStyle.glass => Colors.white.withValues(alpha: 0.78),
      _PlanStyle.blue => Colors.white,
      _PlanStyle.dark => Colors.white.withValues(alpha: 0.9),
    };
    final dividerColor = blue
        ? Colors.white.withValues(alpha: 0.22)
        : Colors.white.withValues(alpha: 0.1);
    // Narx rangi: shisha/ko'k kartada oq; to'q (Premium) kartada ko'k urg'u.
    final priceColor = switch (w.style) {
      _PlanStyle.glass => Colors.white.withValues(alpha: 0.92),
      _PlanStyle.blue => Colors.white,
      _PlanStyle.dark => const Color(0xFF6FA0FF),
    };

    // Barcha qatorlar: "X tarifidagi barchasi" (bo'lsa) + funksiyalar.
    final items = <({String label, bool emphasize})>[
      if (w.includesLabel != null) (label: w.includesLabel!, emphasize: true),
      for (final f in w.features) (label: _featureLabel(f), emphasize: false),
    ];
    final hasMore = items.length > _collapsedCount;
    final visible = (!_expanded && hasMore)
        ? items.sublist(0, _collapsedCount)
        : items;
    final hiddenCount = items.length - _collapsedCount;

    // Pastki tugma: yig'ilgan+ortiqcha bo'lsa "Batafsil"; aks holda "Ulanish"
    // (obuna bo'lsa); ochilgan bepul tarifda "Yig'ish".
    final filled = w.style == _PlanStyle.dark;
    Widget? button;
    if (!_expanded && hasMore) {
      button = _PlanCta(
        label: 'premium.detailsCta'.tr(),
        filled: filled,
        onTap: () => setState(() => _expanded = true),
      );
    } else if (w.ctaLabel != null) {
      button = _PlanCta(
        label: w.ctaLabel!,
        filled: filled,
        loading: w.loading,
        onTap: w.onCta,
      );
    } else if (hasMore) {
      button = _PlanCta(
        label: 'premium.collapseCta'.tr(),
        filled: filled,
        onTap: () => setState(() => _expanded = false),
      );
    }

    final content = Padding(
      padding: const EdgeInsets.all(22),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nom tepada, narx pastda — nom endi qisilmaydi va 2 qatorga
            // sinmaydi (narx bilan bir qatorda emas).
            Text(w.name, style: _unb(24, ls: -0.8)),
            // Bo'sh narx (Android'da xarid yashirilgan rejim) — qator umuman
            // chizilmaydi, karta faqat imkoniyatlar ro'yxatini ko'rsatadi.
            if (w.price.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                w.price,
                style: _unb(17, w: FontWeight.w700, c: priceColor, ls: -0.3),
              ),
            ],
            const SizedBox(height: 18),
            ..._featureRows(visible, featureColor, dividerColor),
            if (!_expanded && hasMore) ...[
              const SizedBox(height: 12),
              Text(
                'premium.moreCount'.tr(namedArgs: {'n': '$hiddenCount'}),
                style: _pop(
                  12.5,
                  w: FontWeight.w500,
                  c: featureColor.withValues(alpha: 0.7),
                ),
              ),
            ],
            if (button != null) ...[const SizedBox(height: 20), button],
          ],
        ),
      ),
    );

    switch (w.style) {
      case _PlanStyle.glass:
        // Frosted shisha — ort fondagi god-ray xiralashadi.
        return ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: content,
            ),
          ),
        );
      case _PlanStyle.blue:
        return DecoratedBox(
          decoration: BoxDecoration(
            color: _blue,
            borderRadius: BorderRadius.circular(28),
          ),
          child: content,
        );
      case _PlanStyle.dark:
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF141C28), Color(0xFF0B111A)],
            ),
          ),
          child: content,
        );
    }
  }
}

class _PlanFeature extends StatelessWidget {
  const _PlanFeature({
    required this.label,
    required this.color,
    this.emphasize = false,
  });

  final String label;
  final Color color;

  /// `true` — "X tarifidagi barchasi" umumlashtiruvchi qator (qalinroq).
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          emphasize ? Icons.check_circle : Icons.check_circle_rounded,
          size: emphasize ? 22 : 21,
          color: color,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: _pop(
              15,
              w: emphasize ? FontWeight.w700 : FontWeight.w500,
              c: color,
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════ Joriy tarif ("Sizning tarifingiz: Premium") ════════════
class _CurrentPlanLabel extends ConsumerWidget {
  const _CurrentPlanLabel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tier = ref.watch(entitlementProvider).valueOrNull?.tier ?? 'free';
    final label = tier == 'free'
        ? 'plans.tierFree'.tr()
        : tier[0].toUpperCase() + tier.substring(1);
    return Text(
      "${'plans.currentPlan'.tr()}: $label",
      style: _pop(13, c: Colors.white.withValues(alpha: 0.55)),
    );
  }
}

// ════════════ To'lov usuli tanlash (Click / Payme) ════════════

/// Tashqi to'lov provayderi tanlovi — pastdan chiqadigan varaq. Faqat
/// backend'da BIR NECHTA provayder sozlangan bo'lsa ko'rsatiladi (bittasi
/// bo'lsa darhol o'sha ochiladi). Natija: `'click'` / `'payme'` yoki `null`
/// (foydalanuvchi yopdi).
class _PayMethodSheet extends StatelessWidget {
  const _PayMethodSheet({
    required this.providers,
    required this.planName,
    required this.priceLabel,
  });

  /// Ko'rsatiladigan provayder kalitlari (`click`, `payme`) — tartib saqlanadi.
  final List<String> providers;
  final String planName;
  final String priceLabel;

  static Future<String?> show(
    BuildContext context, {
    required List<String> providers,
    required String planName,
    required String priceLabel,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PayMethodSheet(
        providers: providers,
        planName: planName,
        priceLabel: priceLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1A2B),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tutqich
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'premium.payMethodTitle'.tr(),
            textAlign: TextAlign.center,
            style: _unb(18, ls: -0.6),
          ),
          const SizedBox(height: 6),
          Text(
            '$planName · $priceLabel',
            textAlign: TextAlign.center,
            style: _pop(13, c: Colors.white.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < providers.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _PayMethodTile(
              brand: _PayBrand.of(providers[i]),
              onTap: () => Navigator.of(context).pop(providers[i]),
            ),
          ],
        ],
      ),
    );
  }
}

/// To'lov provayderi brendi (nom, rasmiy logo, izoh kaliti).
///
/// Logolar — rasmiy SVG'lar (`assets/images/payments/`): Click — click.uz
/// (ko'k belgi + oq yozuv), Payme — cdn.payme.uz gorizontal rangli logo.
/// Ikkalasi ham to'q fon uchun mos, shuning uchun plashka qo'shilmaydi.
class _PayBrand {
  const _PayBrand({
    required this.title,
    required this.asset,
    required this.subtitleKey,
  });

  factory _PayBrand.of(String key) => switch (key) {
    'payme' => const _PayBrand(
      title: 'Payme',
      asset: 'assets/images/payments/payme_logo.svg',
      subtitleKey: 'premium.payViaPayme',
    ),
    _ => const _PayBrand(
      title: 'Click',
      asset: 'assets/images/payments/click_logo.svg',
      subtitleKey: 'premium.payViaClick',
    ),
  };

  /// Semantika (ekran o'quvchi) uchun nom — vizual nom logoning o'zida.
  final String title;
  final String asset;
  final String subtitleKey;
}

/// Bitta to'lov usuli qatori (rasmiy logo + izoh + strelka).
class _PayMethodTile extends StatelessWidget {
  const _PayMethodTile({required this.brand, required this.onTap});

  final _PayBrand brand;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              // Rasmiy logo — belgilangan kenglikda, chapga tekis (Click
              // wordmark'i Payme'nikidan kengroq, ikkalasi bir xil joy oladi).
              SizedBox(
                width: 96,
                height: 44,
                child: Semantics(
                  label: brand.title,
                  image: true,
                  child: SvgPicture.asset(
                    brand.asset,
                    alignment: Alignment.centerLeft,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  brand.subtitleKey.tr(),
                  style: _pop(13, c: Colors.white.withValues(alpha: 0.75)),
                ),
              ),
              Icon(
                SolarIconsBold.altArrowRight,
                size: 20,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════ Oylik / Yillik toggle ════════════
class _BillingToggle extends StatelessWidget {
  const _BillingToggle({required this.yearly, required this.onChanged});

  final bool yearly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _seg('premium.monthly'.tr(), !yearly, () => onChanged(false), null),
            _seg(
              'premium.yearly'.tr(),
              yearly,
              () => onChanged(true),
              'premium.save2m'.tr(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seg(String label, bool active, VoidCallback onTap, String? badge) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: active ? _blue : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: _pop(
                14,
                w: FontWeight.w600,
                c: active ? Colors.white : Colors.white.withValues(alpha: 0.7),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withValues(alpha: 0.22)
                      : const Color(0xFF34C759),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(badge, style: _pop(10.5, w: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tarif kartasi tugmasi. `filled` — ko'k fon + oq matn (Premium); aks holda
/// oq fon + to'q matn (Standart).
class _PlanCta extends StatelessWidget {
  const _PlanCta({
    required this.label,
    required this.filled,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final bool filled;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : _ctaDark;
    return GestureDetector(
      onTap: loading ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 52,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? _blue : Colors.white,
          borderRadius: BorderRadius.circular(999),
        ),
        child: loading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
              )
            : Text(
                label,
                style: _pop(16, w: FontWeight.w600, c: fg),
              ),
      ),
    );
  }
}

// ════════════ Fon: gradient + god-ray porlash ════════════
class _Background extends StatelessWidget {
  const _Background();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // Asosiy diagonal fon: chuqur ko'k (tepa-chap) → qora (past-o'ng).
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_bgTop, _bg],
          stops: [0, 0.93],
        ),
      ),
      child: Stack(
        children: [
          // Tepa-markazda umumiy porlash (nurlar manbai).
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.95),
                  radius: 1.05,
                  colors: [
                    Color(0x8C1859FF), // ko'k 55%
                    Color(0x405D8BFF), // periwinkle 25%
                    Colors.transparent,
                  ],
                  stops: [0, 0.4, 1],
                ),
              ),
            ),
          ),
          // Bir nechta xira aylantirilgan nur "pichoq"lari.
          _ray(angleDeg: -13, opacity: 0.55, width: 120),
          _ray(angleDeg: -4, opacity: 0.7, width: 130),
          _ray(angleDeg: 6, opacity: 0.45, width: 110),
          _ray(angleDeg: 15, opacity: 0.4, width: 100),
        ],
      ),
    );
  }

  /// Bitta xira nur pichog'i — tepa-markazdan ma'lum burchakda tushadi.
  Widget _ray({
    required double angleDeg,
    required double opacity,
    required double width,
  }) {
    return Positioned.fill(
      child: Transform.translate(
        offset: const Offset(0, -140), // manba ekran tepasidan yuqorida
        child: Transform.rotate(
          angle: angleDeg * math.pi / 180,
          alignment: Alignment.topCenter,
          child: Align(
            alignment: Alignment.topCenter,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
              child: Container(
                width: width,
                height: 560,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _rayCore.withValues(alpha: opacity),
                      _rayHalo.withValues(alpha: opacity * 0.5),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.45, 1],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════ Yopish (x) tugmasi ════════════
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: const SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Opacity(
            opacity: 0.35,
            child: Icon(SolarIconsBold.closeCircle, size: 30, color: _icon),
          ),
        ),
      ),
    );
  }
}

// ════════════ "+1k obunachi" badge ════════════
class _SubscribersBadge extends StatelessWidget {
  const _SubscribersBadge();

  static const _avatars = [
    'assets/images/premium/premium_avatar_14.png',
    'assets/images/premium/premium_avatar_15.png',
    'assets/images/premium/premium_avatar_16.png',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _blue,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20 + 2 * (20 - 7.7),
            height: 20,
            child: Stack(
              children: [
                for (var i = 0; i < _avatars.length; i++)
                  Positioned(
                    left: i * (20 - 7.7),
                    child: _Avatar(asset: _avatars[i]),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('premium.subscribers'.tr(), style: _pop(14, w: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF21262A),
        border: Border.all(color: _blue, width: 1.2),
        image: DecorationImage(image: AssetImage(asset), fit: BoxFit.cover),
      ),
    );
  }
}
