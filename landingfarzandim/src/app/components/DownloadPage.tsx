import logoApp from "../../imports/Main/logo_parvoz_app.png";

// ⚠️ APK TARQATISH TO'XTATILDI (2026-08-26). Ilgari bu sahifa
// farzandimedu.uz/app/*.apk fayllariga ishora qilardi. O'sha APK'larning
// versionCode'i backend deploy raqami (500+) edi, Play buildlari esa
// 4 va 7 — Android pastroq versionCode'ni ustiga o'rnatmaydi, ya'ni APK
// o'rnatgan odam Play'dan yangilanish OLA OLMASDI. Fayllar serverdan
// o'chirilgan, havolalar o'lik.
//
// Yuklab olish endi FAQAT do'kondan. Bu qatorlarni APK'ga qaytarmang.
const PARENT_PLAY =
  "https://play.google.com/store/apps/details?id=com.farzandim.parent";
const PARENT_APPSTORE = "https://apps.apple.com/app/id6798972223";
const CHILD_PLAY =
  "https://play.google.com/store/apps/details?id=com.farzandim.growth";

function DownloadIcon({ color }: { color: string }) {
  return (
    <svg className="size-5" viewBox="0 0 24 24" fill="none">
      <path
        d="M12 3v12m0 0l-4-4m4 4l4-4M5 21h14"
        stroke={color}
        strokeWidth="2.2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

function AppCard({
  logo,
  name,
  tagline,
  desc,
  playUrl,
  appStoreUrl,
  accent,
  accentText,
}: {
  logo: string;
  name: string;
  tagline: string;
  desc: string;
  playUrl: string;
  /** Faqat ota-ona ilovasida — bola ilovasi App Store'da yo'q. */
  appStoreUrl?: string;
  accent: string;
  accentText: string;
}) {
  return (
    <div
      className="flex flex-col gap-5 p-6 rounded-[24px]"
      style={{
        background: "rgba(18,21,30,0.72)",
        backdropFilter: "blur(12px)",
        border: "1px solid rgba(255,255,255,0.08)",
      }}
    >
      {/* Logo + nom */}
      <div className="flex items-center gap-4">
        <div
          className="shrink-0 overflow-hidden"
          style={{
            width: 76,
            height: 76,
            borderRadius: 20,
            background: "#ffffff",
            boxShadow: `0 10px 30px -8px ${accent}55, 0 0 0 1px rgba(255,255,255,0.06)`,
          }}
        >
          <img
            src={logo}
            alt={`${name} logo`}
            style={{ width: "100%", height: "100%", objectFit: "contain", display: "block" }}
          />
        </div>
        <div className="min-w-0">
          <h3 style={{ fontFamily: "Inter, sans-serif", fontWeight: 700, fontSize: 22, color: "white", lineHeight: "26px" }}>
            {name}
          </h3>
          <p style={{ fontFamily: "Inter, sans-serif", fontWeight: 600, fontSize: 13, color: accent, marginTop: 2 }}>
            {tagline}
          </p>
        </div>
      </div>

      {/* Tavsif */}
      <p style={{ fontFamily: "Inter, sans-serif", fontWeight: 400, fontSize: 14, lineHeight: "21px", color: "rgba(255,255,255,0.72)", flex: 1 }}>
        {desc}
      </p>

      {/* Do'kondan yuklab olish */}
      <a
        href={playUrl}
        target="_blank"
        rel="noopener noreferrer"
        className="flex items-center justify-center gap-2 rounded-full py-3.5 px-5 transition-transform active:scale-95"
        style={{ background: accent, textDecoration: "none" }}
      >
        <DownloadIcon color={accentText} />
        <span style={{ fontFamily: "Inter, sans-serif", fontWeight: 700, fontSize: 16, color: accentText }}>
          Play Market
        </span>
      </a>
      {appStoreUrl && (
        <a
          href={appStoreUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="flex items-center justify-center gap-2 rounded-full py-3 px-5 transition-transform active:scale-95"
          style={{ border: "1.5px solid rgba(255,255,255,0.25)", textDecoration: "none" }}
        >
          <span style={{ fontFamily: "Inter, sans-serif", fontWeight: 600, fontSize: 15, color: "#ffffff" }}>
            App Store
          </span>
        </a>
      )}
      <span style={{ fontFamily: "Inter, sans-serif", fontWeight: 500, fontSize: 12, color: "rgba(255,255,255,0.45)", textAlign: "center" }}>
        {appStoreUrl ? "Android va iPhone" : "Android"}
      </span>
    </div>
  );
}

export function DownloadPage() {
  return (
    <div
      className="min-h-screen flex flex-col items-center relative overflow-x-hidden"
      style={{ background: "#060916", fontFamily: "Inter, sans-serif" }}
    >
      {/* Orqa fon glow */}
      <div
        className="absolute inset-0 pointer-events-none"
        style={{ background: "radial-gradient(ellipse 70% 50% at 50% 0%, rgba(79,134,255,0.18) 0%, transparent 70%)" }}
      />

      {/* Header */}
      <div className="relative w-full max-w-3xl px-6 pt-8 flex items-center justify-between">
        <span style={{ fontFamily: "Inter, sans-serif", fontWeight: 600, fontSize: 20, letterSpacing: "-0.28px", color: "white" }}>
          Parvoz
        </span>
        <a
          href="#"
          onClick={(e) => {
            e.preventDefault();
            window.location.hash = "";
          }}
          className="flex items-center gap-1.5 cursor-pointer hover:opacity-80 transition-opacity"
          style={{ textDecoration: "none" }}
        >
          <svg className="size-4" viewBox="0 0 24 24" fill="none">
            <path d="M15 18l-6-6 6-6" stroke="rgba(255,255,255,0.7)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
          <span style={{ fontFamily: "Inter, sans-serif", fontWeight: 500, fontSize: 14, color: "rgba(255,255,255,0.7)" }}>Bosh sahifa</span>
        </a>
      </div>

      {/* Sarlavha */}
      <div className="relative text-center px-6 mt-12 max-w-xl">
        <h1 style={{ fontFamily: "Inter, sans-serif", fontWeight: 700, fontSize: "clamp(26px, 5vw, 34px)", lineHeight: 1.2, letterSpacing: "-0.4px", color: "white" }}>
          Ilovani yuklab oling
        </h1>
        <p style={{ fontFamily: "Inter, sans-serif", fontWeight: 500, fontSize: 16, lineHeight: "24px", color: "rgba(255,255,255,0.7)", marginTop: 10 }}>
          Sizga qaysi ilova kerak?
        </p>
      </div>

      {/* 2 ta ilova kartasi */}
      <div className="relative w-full max-w-3xl px-6 mt-8 mb-12 grid grid-cols-1 md:grid-cols-2 gap-4">
        <AppCard
          logo={logoApp}
          name="Parvoz Parents"
          tagline="Ota-onalar uchun"
          desc="Farzandingizni bir ilovadan kuzating: real vaqtda joylashuv va geo-zonalar, ekran vaqti hamda ilovalar nazorati, SOS signal va bildirishnomalar."
          playUrl={PARENT_PLAY}
          appStoreUrl={PARENT_APPSTORE}
          accent="#4f86ff"
          accentText="#ffffff"
        />
        <AppCard
          logo={logoApp}
          name="Parvoz Growth"
          tagline="Bolalar uchun"
          desc="Bolangizga xavfsiz ta'limiy kontent — videolar, audiokitoblar va bilim konkurslari. Hammasi yoshiga mos va ota-ona nazoratida."
          playUrl={CHILD_PLAY}
          accent="#22d3ee"
          accentText="#04222b"
        />
      </div>
    </div>
  );
}
