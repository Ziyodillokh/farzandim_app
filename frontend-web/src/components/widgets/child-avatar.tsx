'use client';

import Image from 'next/image';
import { cn } from '@/lib/utils';

/**
 * ChildAvatar — Flutter ChildAvatar 1:1 ekvivalenti.
 * Dumaloq avatar — agar photoPath bo'lsa rasm, yo'q bo'lsa ism harfi.
 */
interface Props {
  name: string;
  photoUrl?: string | null;
  size?: number;
  className?: string;
}

export function ChildAvatar({ name, photoUrl, size = 56, className }: Props) {
  const initial = name?.[0]?.toUpperCase() || '?';

  return (
    <div
      className={cn(
        'relative flex items-center justify-center overflow-hidden rounded-full bg-primary',
        className,
      )}
      style={{ width: size, height: size }}
    >
      {photoUrl ? (
        <Image src={photoUrl} alt={name} fill className="object-cover" />
      ) : (
        <span
          className="font-bold text-background"
          style={{ fontSize: size * 0.4 }}
        >
          {initial}
        </span>
      )}
    </div>
  );
}
