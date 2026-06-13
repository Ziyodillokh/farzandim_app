// ─────────────────────────────────────────────────────────────────────
// Interest labels — bola onboarding'da tanlagan ID → label/icon
// ─────────────────────────────────────────────────────────────────────
//
// Backend `Child.interests` ID'larini admin paneldagi chip ko'rinishida
// foydalanuvchiga tanish so'zlar (Kitoblar, Multfilmlar...) bilan
// ko'rsatish uchun.
//
// Truth source — farzandim_child onboarding interest_options.dart. Ikkala
// ro'yxat qo'lda sinxron tutiladi (12 ta variant).

import type { LucideIcon } from 'lucide-react';
import {
  BookOpen,
  Film,
  Trophy,
  Music,
  Cat,
  Rocket,
  Cpu,
  Palette,
  FlaskConical,
  Gamepad2,
  Map as MapIcon,
  UtensilsCrossed,
  Tag,
} from 'lucide-react';

export interface InterestMeta {
  label: string;
  Icon: LucideIcon;
}

const INTEREST_LABELS: Record<string, InterestMeta> = {
  book: { label: 'Kitoblar', Icon: BookOpen },
  cartoon: { label: 'Multfilmlar', Icon: Film },
  sport: { label: 'Sport', Icon: Trophy },
  music: { label: 'Musiqa', Icon: Music },
  animals: { label: 'Hayvonlar', Icon: Cat },
  space: { label: 'Kosmos', Icon: Rocket },
  tech: { label: 'Texnologiya', Icon: Cpu },
  art: { label: "San'at", Icon: Palette },
  science: { label: 'Fan', Icon: FlaskConical },
  games: { label: "O'yinlar", Icon: Gamepad2 },
  travel: { label: 'Sayohat', Icon: MapIcon },
  food: { label: 'Ovqat', Icon: UtensilsCrossed },
};

/// Noma'lum id uchun fallback (backend yangi tag qo'shgan, admin panel
/// hali yangilanmagan holatlarda).
export function interestMetaFor(id: string): InterestMeta {
  return INTEREST_LABELS[id] ?? { label: id, Icon: Tag };
}
