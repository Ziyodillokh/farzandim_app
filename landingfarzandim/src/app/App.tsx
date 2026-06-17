import { useSyncExternalStore } from "react";
import { FarzandimPage } from "./components/FarzandimPage";
import { DownloadPage } from "./components/DownloadPage";

// Yengil hash-routing — statik hostda server sozlamasisiz ishlaydi.
// QR `#yuklash` ni kodlaydi → skaner qilinganda DownloadPage ochiladi.
function subscribe(cb: () => void) {
  window.addEventListener("hashchange", cb);
  return () => window.removeEventListener("hashchange", cb);
}
function getHash() {
  return window.location.hash;
}

export default function App() {
  const hash = useSyncExternalStore(subscribe, getHash, () => "");
  const route = hash.replace(/^#\/?/, "");

  if (route === "yuklash") return <DownloadPage />;
  return <FarzandimPage />;
}
