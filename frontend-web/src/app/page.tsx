import Image from 'next/image';
import { PrimaryButton } from '@/components/widgets/primary-button';

/**
 * Welcome ekran — Flutter `welcome_screen.dart` 1:1 ko'chirilgan.
 *
 * Layout: 3 qatlamli stack:
 *   1. Fon rasmi (welcome_bg.jpg, BoxFit.cover)
 *   2. Yuqoridan transparent → pastdan qora 60% gradient overlay
 *   3. Mazmun (logo + sarlavhalar + tugma) SafeArea ichida
 *
 * Matnlar uz.json'dan (auth.welcome.*).
 */
export default function WelcomePage() {
  return (
    <main className="relative flex min-h-screen flex-col overflow-hidden bg-background">
      {/* Qatlam 1: fon rasmi (welcome_bg.jpg, BoxFit.cover) */}
      <Image
        src="/assets/images/welcome_bg.jpg"
        alt=""
        fill
        priority
        className="object-cover"
      />

      {/* Qatlam 2: qorong'i overlay (matn o'qilishi uchun) */}
      <div className="absolute inset-0 bg-gradient-to-b from-transparent to-black/60" />

      {/* Qatlam 3: mazmun */}
      <div className="relative z-10 mx-auto flex w-full max-w-md flex-1 flex-col px-6">
        {/* 80px yuqoridan bo'shliq */}
        <div className="h-20" />

        {/* Brand: square brand (LOGO yuqorida) + icon (accent pastda) */}
        <div className="flex flex-col items-center">
          <Image
            src="/assets/app_icon/parent_app_icon_white.png"
            alt="Farzandim"
            width={120}
            height={120}
            priority
            className="object-contain"
          />
          <div className="h-4" />
          <Image
            src="/assets/icons/parent_logo_icon.png"
            alt="Farzandim Logo"
            width={80}
            height={40}
            priority
            className="object-contain"
          />
        </div>

        <div className="h-6" />

        {/* Asosiy sarlavha — 32sp Bold oq, markazda (Flutter headlineXL) */}
        <h1 className="text-center text-[32px] font-bold leading-tight text-white">
          Xush kelibsiz
        </h1>

        <div className="h-2" />

        {/* Subtitle — 17sp oq, markazda (Flutter bodyM) */}
        <p className="text-center text-[17px] leading-[1.4] text-white">
          Farzandingizni onlayn himoya qiling
        </p>

        {/* Spacer — tugmalarni pastga itaradi */}
        <div className="flex-1" />

        {/* PrimaryButton — Telegram orqali davom etish */}
        <PrimaryButton href="/login">Telegram orqali davom etish</PrimaryButton>

        {/* 32px pastki bo'shliq */}
        <div className="h-8" />
      </div>
    </main>
  );
}
