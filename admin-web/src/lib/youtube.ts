// YouTube havolasidan 11 belgili video ID. Bola ilovasidagi
// (video_model.dart) mantiq bilan AYNAN bir xil: ID youtube domeni oldidan
// kelishi shart, shunda .mp4?v=... kabi to'g'ridan-to'g'ri havolalar xato
// aniqlanmaydi. youtu.be / watch?v= / embed/ / shorts/ / live/ ni qo'llaydi.
export function youtubeId(url: string): string | null {
  const m = url.match(
    /(?:youtu\.be\/|youtube\.com\/(?:watch\?(?:[^ ]*&)?v=|embed\/|shorts\/|live\/))([\w-]{11})/,
  );
  return m ? m[1] : null;
}
