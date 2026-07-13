import main1 from "../../assets/main1.png";
import main2 from "../../assets/main2.png";
import main3 from "../../assets/main3.png";
import logoApp from "../../imports/Main/logo_parvoz_app.png";
import svgPaths from "../../imports/Main/svg-35b9599amp";
import { QRCodeSVG } from "qrcode.react";

// ──────────────────────────────────────────────
// Atoms
// ──────────────────────────────────────────────

function LogoIcon() {
  // Farzandimning haqiqiy logosi — dumaloq plitka (app-icon ko'rinishi).
  return (
    <div
      className="relative shrink-0 overflow-hidden"
      style={{
        width: 40,
        height: 40,
        borderRadius: 11,
        background: "#ffffff",
        boxShadow: "0 6px 18px -6px rgba(0,0,0,0.55), 0 0 0 1px rgba(255,255,255,0.10)",
      }}
    >
      <img
        src={logoApp}
        alt="Parvoz logo"
        style={{ width: "100%", height: "100%", objectFit: "cover", display: "block" }}
      />
    </div>
  );
}

function Logo() {
  return (
    <div className="flex items-center gap-2">
      <LogoIcon />
      <span
        style={{ fontFamily: "Inter, sans-serif", fontWeight: 600, fontSize: 24, letterSpacing: "-0.28px", color: "white" }}
      >
        Parvoz
      </span>
    </div>
  );
}

// App store badges
function AppStoreBadge() {
  return (
    <div className="bg-[#c6ff7f] rounded px-2.5 py-1.5 flex items-center cursor-pointer hover:opacity-90 transition-opacity">
      <svg className="h-4" fill="none" viewBox="0 0 65 16">
        <g clipPath="url(#as-clip)">
          <path d={svgPaths.p1326af00} fill="black" />
          <path d={svgPaths.p235cb510} fill="black" />
          <path d={svgPaths.p19e90c00} fill="black" />
          <path d={svgPaths.p253dc400} fill="black" />
          <path d={svgPaths.p15441180} fill="black" />
          <path d={svgPaths.p1a5d8400} fill="black" />
          <path d={svgPaths.p30084e80} fill="black" />
          <path d={svgPaths.p200b7a80} fill="black" />
          <path d={svgPaths.p15b74e00} fill="black" />
          <path d={svgPaths.p2745e600} fill="black" />
          <path d={svgPaths.p25c30b40} fill="black" />
          <path d={svgPaths.p1a0fa880} fill="black" />
          <path d={svgPaths.p37e51d00} fill="black" />
          <path d={svgPaths.p6650500} fill="black" />
          <path d={svgPaths.p127ab700} fill="black" />
          <path d={svgPaths.p2f232380} fill="black" />
          <path d={svgPaths.p2a630940} fill="black" />
          <path d={svgPaths.p27c43c00} fill="black" />
          <path d={svgPaths.p14ef5a00} fill="black" />
          <path d={svgPaths.p3a0f5a00} fill="black" />
          <path d={svgPaths.p33c50500} fill="black" />
          <path d={svgPaths.p9bd500} fill="black" />
          <path d={svgPaths.p1f19aef2} fill="black" />
        </g>
        <defs><clipPath id="as-clip"><rect fill="white" height="16" width="65" /></clipPath></defs>
      </svg>
    </div>
  );
}

function GooglePlayBadge() {
  return (
    <div className="bg-[#c6ff7f] rounded px-2.5 py-1.5 flex items-center cursor-pointer hover:opacity-90 transition-opacity">
      <svg className="h-4" fill="none" viewBox="0 0 67 16">
        <g clipPath="url(#gp-clip)">
          <path d={svgPaths.p3048e400} fill="black" />
          <path clipRule="evenodd" d={svgPaths.pfb63300} fill="black" fillRule="evenodd" />
          <path clipRule="evenodd" d={svgPaths.p10107d00} fill="url(#gp-g0)" fillRule="evenodd" />
          <path clipRule="evenodd" d={svgPaths.p36b2980} fill="url(#gp-g1)" fillRule="evenodd" />
          <path clipRule="evenodd" d={svgPaths.p25df0800} fill="url(#gp-g2)" fillRule="evenodd" />
          <path clipRule="evenodd" d={svgPaths.p18b05d00} fill="url(#gp-g3)" fillRule="evenodd" />
          <path clipRule="evenodd" d={svgPaths.p5232b00} fill="black" fillRule="evenodd" opacity="0.2" />
          <path clipRule="evenodd" d={svgPaths.p28c54e00} fill="black" fillRule="evenodd" opacity="0.12" />
          <path clipRule="evenodd" d={svgPaths.p296c4780} fill="white" fillRule="evenodd" opacity="0.25" />
        </g>
        <defs>
          <linearGradient gradientUnits="userSpaceOnUse" id="gp-g0" x1="6.80386" x2="-4.64482" y1="1.13735" y2="4.13322">
            <stop stopColor="#00BEFF" /><stop offset="1" stopColor="#00E3FF" />
          </linearGradient>
          <linearGradient gradientUnits="userSpaceOnUse" id="gp-g1" x1="13.7307" x2="-0.195703" y1="7.75587" y2="7.75587">
            <stop stopColor="#FFE000" /><stop offset="1" stopColor="#FF9C00" />
          </linearGradient>
          <linearGradient gradientUnits="userSpaceOnUse" id="gp-g2" x1="8.54607" x2="-0.870355" y1="9.1022" y2="24.6669">
            <stop stopColor="#FF3A44" /><stop offset="1" stopColor="#C31162" />
          </linearGradient>
          <linearGradient gradientUnits="userSpaceOnUse" id="gp-g3" x1="-1.54421" x2="2.65689" y1="-3.86032" y2="3.09122">
            <stop stopColor="#32A071" /><stop offset="1" stopColor="#00F076" />
          </linearGradient>
          <clipPath id="gp-clip"><rect fill="white" height="16" width="67" /></clipPath>
        </defs>
      </svg>
    </div>
  );
}

function AppGalleryBadge() {
  return (
    <div className="bg-[#c6ff7f] rounded px-2.5 py-1.5 flex items-center cursor-pointer hover:opacity-90 transition-opacity">
      <svg className="h-4" fill="none" viewBox="0 0 70 16">
        <g clipPath="url(#ag-clip)">
          <path d={svgPaths.p26b09c80} fill="black" />
          <path d={svgPaths.p599b330} fill="black" />
          <path d={svgPaths.p4f21d00} fill="black" />
          <path d={svgPaths.p14fbe6f0} fill="black" />
          <path d={svgPaths.p3fdacc00} fill="black" />
          <path d={svgPaths.p1aa2bac0} fill="black" />
          <path d={svgPaths.p248bfe80} fill="black" />
          <path d={svgPaths.p2d5c9800} fill="black" />
          <path d={svgPaths.p39fbe00} fill="black" />
          <path d={svgPaths.p4f94af0} fill="black" />
          <path d={svgPaths.p27e68700} fill="black" />
          <path d={svgPaths.p3a416d00} fill="black" />
          <path d={svgPaths.p126cda00} fill="black" />
          <path d={svgPaths.pe0667f0} fill="black" />
          <path d={svgPaths.p2980e300} fill="black" />
          <path d={svgPaths.pe178d80} fill="black" />
          <path d={svgPaths.p38b9a000} fill="black" />
          <path d={svgPaths.p33c7c00} fill="black" />
          <path d={svgPaths.p5f93000} fill="black" />
          <path d={svgPaths.p31d4e700} fill="black" />
          <path d={svgPaths.p21e65900} fill="black" />
          <path clipRule="evenodd" d={svgPaths.p277c1500} fill="#C8102E" fillRule="evenodd" />
          <path d={svgPaths.p7ef7c00} fill="white" />
          <path d={svgPaths.p1bf7c80} fill="white" />
        </g>
        <defs><clipPath id="ag-clip"><rect fill="white" height="16" width="70" /></clipPath></defs>
      </svg>
    </div>
  );
}

// Social icon button
function SocialBtn({ icon }: { icon: React.ReactNode }) {
  return (
    <div className="bg-[#c6ff7f] flex items-center px-2 py-1.5 rounded-xl cursor-pointer hover:opacity-90 transition-opacity">
      <div className="bg-[rgba(255,255,255,0.06)] p-0.5 rounded-lg">
        {icon}
      </div>
    </div>
  );
}

// Feature chip
function FeatureChip({ label }: { label: string }) {
  return (
    <div className="fz-chip bg-[#060916] flex gap-1.5 items-center px-2 py-1.5 relative rounded-xl border border-[rgba(255,255,255,0.1)] shrink-0">
      <div className="bg-[rgba(255,255,255,0.06)] p-0.5 rounded-lg">
        <svg className="size-5" fill="none" viewBox="0 0 20 20">
          <path d={svgPaths.p89ade00} fill="white" />
        </svg>
      </div>
      <span style={{ fontFamily: "Inter, sans-serif", fontWeight: 400, fontSize: 14, color: "white", whiteSpace: "nowrap" }}>
        {label}
      </span>
    </div>
  );
}

// ──────────────────────────────────────────────
// Sections
// ──────────────────────────────────────────────

function ComingSoonBanner() {
  return (
    <div className="w-full bg-red-600 flex items-center justify-center py-3 px-4 z-50 relative">
      <div className="flex items-center gap-3">
        <div className="w-2 h-2 rounded-full bg-white animate-pulse" />
        <span
          style={{
            fontFamily: "Inter, sans-serif",
            fontWeight: 700,
            fontSize: 14,
            letterSpacing: "0.15em",
            color: "white",
            textTransform: "uppercase",
          }}
        >
          TEZ KUNDA
        </span>
        <div className="w-2 h-2 rounded-full bg-white animate-pulse" />
      </div>
    </div>
  );
}

function NavBar() {
  return (
    <nav className="flex items-center justify-center pt-8 pb-0 px-6">
      <Logo />
    </nav>
  );
}

function HeroSection() {
  return (
    <div className="flex flex-col items-center text-center gap-5 px-6 max-w-3xl mx-auto">
      <h1
        style={{
          fontFamily: "Inter, sans-serif",
          fontWeight: 600,
          fontSize: "clamp(28px, 5vw, 40px)",
          lineHeight: 1.2,
          letterSpacing: "-0.4px",
          color: "white",
        }}
      >
        Bolalar uchun xavfsiz va foydali kontent platformasi
      </h1>
      <p
        style={{
          fontFamily: "Inter, sans-serif",
          fontWeight: 500,
          fontSize: "clamp(15px, 2.5vw, 18px)",
          lineHeight: "26px",
          letterSpacing: "-0.04px",
          color: "rgba(255,255,255,0.8)",
        }}
      >
        Videolar, audiokitoblar va bilim konkurslari - barchasi nazorat ostida
      </p>
    </div>
  );
}

function PhoneMockups() {
  return (
    <div className="relative mt-8 flex items-end justify-center" style={{ minHeight: 320 }}>
      {/* Purple glow behind phones */}
      <div
        className="absolute inset-0 pointer-events-none"
        style={{
          background: "radial-gradient(ellipse 60% 70% at 50% 70%, rgba(138,98,249,0.4) 0%, transparent 70%)",
        }}
      />

      {/* Three phones in a flex row that overlap via negative margins */}
      <div className="relative flex items-end justify-center" style={{ gap: 0 }}>
        {/* Left phone – rotated back */}
        <div
          style={{
            width: "clamp(110px, 15vw, 184px)",
            height: "clamp(218px, 30vw, 370px)",
            transform: "rotate(-8deg)",
            transformOrigin: "bottom center",
            marginRight: "clamp(-30px, -4vw, -48px)",
            zIndex: 1,
            flexShrink: 0,
          }}
        >
          <img
            src={main2}
            alt="Bola ilovasi — videolar va audiokitoblar"
            style={{ width: "100%", height: "100%", objectFit: "contain", display: "block" }}
          />
        </div>

        {/* Center phone – upright, on top */}
        <div
          style={{
            width: "clamp(120px, 16vw, 189px)",
            height: "clamp(238px, 32vw, 387px)",
            zIndex: 10,
            flexShrink: 0,
          }}
        >
          <img
            src={main1}
            alt="Ota-ona paneli — nazorat va reyting"
            style={{ width: "100%", height: "100%", objectFit: "contain", display: "block" }}
          />
        </div>

        {/* Right phone – rotated forward */}
        <div
          style={{
            width: "clamp(110px, 15vw, 184px)",
            height: "clamp(218px, 30vw, 370px)",
            transform: "rotate(8deg)",
            transformOrigin: "bottom center",
            marginLeft: "clamp(-30px, -4vw, -48px)",
            zIndex: 1,
            flexShrink: 0,
          }}
        >
          <img
            src={main3}
            alt="Faollik statistikasi — vaqt va ilovalar"
            style={{ width: "100%", height: "100%", objectFit: "contain", display: "block" }}
          />
        </div>
      </div>
    </div>
  );
}

function DownloadCard() {
  // Skaner qilinganda yuklab olish (tanlov) sahifasi ochiladi. Origin
  // dinamik — qaysi domenda joylashtirilsa, QR o'shanga moslashadi.
  const downloadUrl = (typeof window !== "undefined" ? window.location.origin : "") + "/#yuklash";
  return (
    <div
      className="flex flex-col gap-5 p-5 rounded-[20px]"
      style={{ background: "rgba(18,21,30,0.7)", backdropFilter: "blur(12px)", border: "1px solid rgba(255,255,255,0.08)" }}
    >
      {/* Top row: text + QR */}
      <div className="flex items-start justify-between gap-4">
        <div className="flex flex-col gap-2">
          <div>
            <p style={{ fontFamily: "Inter, sans-serif", fontWeight: 600, fontSize: 18, color: "white", lineHeight: "24px" }}>
              Mobil ilovamizni
            </p>
            <p style={{ fontFamily: "Inter, sans-serif", fontWeight: 600, fontSize: 18, color: "white", lineHeight: "24px" }}>
              yuklab oling
            </p>
          </div>
          <p style={{ fontFamily: "Inter, sans-serif", fontWeight: 400, fontSize: 12, color: "white", lineHeight: "16px" }}>
            QR'ni skanerlang yoki bosing —<br />ilovani tanlab yuklab oling!
          </p>
        </div>
        <a
          href="#yuklash"
          aria-label="Ilovani yuklab olish sahifasi"
          className="bg-white rounded-lg p-2 shrink-0 block cursor-pointer hover:opacity-95 transition-opacity"
        >
          <QRCodeSVG value={downloadUrl} size={84} fgColor="#060916" bgColor="#FFFFFF" level="M" marginSize={1} />
        </a>
      </div>
      {/* Badge row */}
      <div className="flex gap-2.5 flex-wrap">
        <AppStoreBadge />
        <GooglePlayBadge />
        <AppGalleryBadge />
      </div>
    </div>
  );
}

// Social icons inline SVG paths
function FacebookIcon() {
  return (
    <svg className="size-5" fill="none" viewBox="0 0 20 20">
      <g clipPath="url(#fb-c)">
        <path d={svgPaths.p699c500} fill="black" />
      </g>
      <defs><clipPath id="fb-c"><rect fill="white" height="20" width="20" /></clipPath></defs>
    </svg>
  );
}

function InstagramIcon() {
  return (
    <svg className="size-6" fill="none" viewBox="0 0 24 24">
      <path d={svgPaths.pc760d00} fill="black" />
    </svg>
  );
}

function TelegramIcon() {
  return (
    <svg className="size-6" fill="none" viewBox="0 0 24 24">
      <path d={svgPaths.pc5d4400} fill="black" />
    </svg>
  );
}

function YoutubeIcon() {
  return (
    <svg className="size-6" fill="none" viewBox="0 0 24 24">
      <path d={svgPaths.p217a0c10} fill="black" />
    </svg>
  );
}

function PhoneIcon() {
  return (
    <svg className="size-6" fill="none" viewBox="0 0 24 24">
      <path d={svgPaths.p25da1400} fill="black" />
    </svg>
  );
}

function LocationIcon() {
  return (
    <svg className="h-[21px] w-[18px]" fill="none" viewBox="0 0 18 21">
      <g clipPath="url(#loc-c)">
        <path d={svgPaths.p18e25b80} fill="black" />
      </g>
      <defs><clipPath id="loc-c"><rect fill="white" height="21" width="18" /></clipPath></defs>
    </svg>
  );
}

function SocialCard() {
  return (
    <div
      className="flex flex-col gap-3 p-5 rounded-[20px]"
      style={{ background: "rgba(18,21,30,0.7)", backdropFilter: "blur(12px)", border: "1px solid rgba(255,255,255,0.08)" }}
    >
      {/* Social row */}
      <div className="flex gap-2 flex-wrap">
        <SocialBtn icon={<FacebookIcon />} />
        <SocialBtn icon={<InstagramIcon />} />
        <SocialBtn icon={<TelegramIcon />} />
        <SocialBtn icon={<YoutubeIcon />} />
        <SocialBtn icon={<PhoneIcon />} />
      </div>
      {/* Address */}
      <div className="bg-[#c6ff7f] flex gap-1.5 items-center px-2 py-1.5 rounded-xl cursor-pointer hover:opacity-90 transition-opacity">
        <div className="bg-[rgba(255,255,255,0.06)] p-0.5 rounded-lg">
          <LocationIcon />
        </div>
        <span style={{ fontFamily: "Inter, sans-serif", fontWeight: 400, fontSize: 14, color: "black" }}>
          Toshkent sh, Alisher Navoiy ko'chasi, 146A
        </span>
      </div>
    </div>
  );
}

const allFeatures = [
  "Xavfsiz kontent",
  "Audiokitoblar va videolar",
  "Ota-ona nazorati",
  "Kontent nazorati",
  "Harakatlar tarixi",
  "Bir tomonlama audio",
  "Bildirishnomalarni ulash",
  "Hisobot",
  "O'yinlar",
  "Vaqt nazorati",
  "Konkurslar",
  "Yosh filtri",
  "Yoshga mos kontent",
  "Jonli joylashuv",
  "Hudud nazorati",
  "Ekranni ko'rish",
];

const row1Features = allFeatures.slice(0, 8);
const row2Features = allFeatures.slice(8);

// Seamless marquee + chip hover. prefers-reduced-motion'da to'liq o'chadi.
const fzMarqueeCss = `
@keyframes fz-marq-ltr { from { transform: translate3d(0,0,0); } to { transform: translate3d(-50%,0,0); } }
@keyframes fz-marq-rtl { from { transform: translate3d(-50%,0,0); } to { transform: translate3d(0,0,0); } }
@keyframes fz-lime-pulse { 0%,100% { box-shadow: 0 0 0 0 rgba(198,255,127,0); } 50% { box-shadow: 0 0 16px 1px rgba(198,255,127,0.35); } }
.fz-marquee { position: relative; width: 100vw; margin-left: calc(50% - 50vw); overflow: hidden; -webkit-mask-image: linear-gradient(90deg, transparent, #000 7%, #000 93%, transparent); mask-image: linear-gradient(90deg, transparent, #000 7%, #000 93%, transparent); }
.fz-track { display: flex; gap: 12px; width: max-content; will-change: transform; animation: fz-marq-ltr 42s linear infinite; }
.fz-track--rtl { animation-name: fz-marq-rtl; animation-duration: 50s; }
.fz-marquee:hover .fz-track { animation-play-state: paused; }
.fz-chip { transition: transform .25s cubic-bezier(.22,1,.36,1), border-color .25s; }
.fz-chip:hover { transform: translateY(-3px) scale(1.04); border-color: rgba(198,255,127,0.55); animation: fz-lime-pulse 1.6s ease-in-out infinite; }
@media (prefers-reduced-motion: reduce) { .fz-track { animation: none !important; } .fz-chip:hover { animation: none !important; } }
`;

// Bitta uzilishsiz suzuvchi qator. Chiplar 4x dublikat — har qanday ekran
// kengligida (mobil/keng desktop) loop uzilmaydi; translateX -50% bilan qaytadi.
function MarqueeRow({ items, reverse = false }: { items: string[]; reverse?: boolean }) {
  const loop = [...items, ...items, ...items, ...items];
  return (
    <div className="fz-marquee">
      <div className={`fz-track${reverse ? " fz-track--rtl" : ""}`}>
        {loop.map((f, i) => (
          <FeatureChip key={`${f}-${i}`} label={f} />
        ))}
      </div>
    </div>
  );
}

// Desktop + mobil: ikki qator qarama-qarshi suzadi (1 o'ngdan-chapga, 2 chapdan-o'ngga).
function FeatureGrid() {
  return (
    <div className="flex flex-col gap-3 w-full pb-8">
      <style>{fzMarqueeCss}</style>
      <MarqueeRow items={row1Features} />
      <MarqueeRow items={row2Features} reverse />
    </div>
  );
}

// Background gradient SVG
function BackgroundSVG() {
  return (
    <div className="absolute inset-0 pointer-events-none overflow-hidden">
      <svg
        className="absolute w-full h-full"
        fill="none"
        preserveAspectRatio="xMidYMid slice"
        viewBox="0 0 1440 900"
      >
        <path
          clipRule="evenodd"
          d={svgPaths.p9e29a00}
          fill="url(#bg-grad)"
          fillOpacity="0.14"
          fillRule="evenodd"
        />
        <defs>
          <linearGradient gradientUnits="userSpaceOnUse" id="bg-grad" x1="720" x2="720" y1="0" y2="900">
            <stop stopColor="white" stopOpacity="0.2" />
            <stop offset="1" stopColor="white" stopOpacity="0" />
          </linearGradient>
        </defs>
      </svg>
    </div>
  );
}

// ──────────────────────────────────────────────
// Page
// ──────────────────────────────────────────────

export function FarzandimPage() {
  return (
    <div className="min-h-screen flex flex-col overflow-x-hidden" style={{ background: "#060916", fontFamily: "Inter, sans-serif" }}>
      {/* COMING SOON banner */}
      <ComingSoonBanner />

      {/* Main content */}
      <div className="relative flex-1 flex flex-col">
        <BackgroundSVG />

        {/* Nav */}
        <NavBar />

        {/* Hero */}
        <div className="mt-12 md:mt-16 px-4">
          <HeroSection />
        </div>

        {/* Phone mockups */}
        <PhoneMockups />

        {/* Bottom panels – stacked on mobile, side by side on desktop */}
        <div className="relative z-10 flex flex-col md:flex-row gap-4 justify-center px-4 md:px-8 mt-6 max-w-4xl mx-auto w-full">
          <div className="flex-1 min-w-0 md:max-w-[325px]">
            <DownloadCard />
          </div>
          <div className="flex-1 min-w-0 md:max-w-[325px]">
            <SocialCard />
          </div>
        </div>

        {/* Feature chips */}
        <div className="mt-8 px-4">
          <FeatureGrid />
        </div>
      </div>
    </div>
  );
}
