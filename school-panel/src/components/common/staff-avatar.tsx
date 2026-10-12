'use client';

import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { useStaffAvatar } from '@/features/profile/hooks';
import { staffAvatarSrc } from '@/lib/staff-avatar';
import { cn, initials } from '@/lib/utils';

type Size = 'xs' | 'sm' | 'md' | 'lg' | 'xl';

const SIZES: Record<Size, string> = {
  xs: 'h-6 w-6 text-[0.55rem]',
  sm: 'h-8 w-8 text-[0.65rem]',
  md: 'h-10 w-10 text-xs',
  lg: 'h-12 w-12 text-sm',
  xl: 'h-24 w-24 rounded-[1.75rem] text-2xl',
};

/**
 * Xodim avatari: yuklangan rasm → chizilgan portret → bosh harflar.
 * `photo`/`portrait` berilmasa, `staffId` bo'yicha umumiy keshdan olinadi.
 */
export function StaffAvatar({
  staffId,
  name,
  photo,
  portrait,
  size = 'md',
  className,
}: {
  staffId?: string | null;
  name?: string;
  photo?: string | null;
  portrait?: string | null;
  size?: Size;
  className?: string;
}) {
  const explicit = photo !== undefined || portrait !== undefined;
  const lookup = useStaffAvatar(explicit ? null : staffId);
  const info = lookup.data;
  const src = staffAvatarSrc({ photo: explicit ? photo : info?.photo, portrait: explicit ? portrait : info?.portrait });
  const label = name ?? info?.fullName ?? '';
  return (
    <Avatar className={cn(SIZES[size], size === 'xl' && 'rounded-[1.75rem]', className)}>
      {src && <AvatarImage src={src} alt={label} />}
      <AvatarFallback className={cn('bg-gradient-to-br from-brand-400 to-brand-800 font-semibold text-white', size === 'xl' && 'rounded-[1.75rem]')}>
        {initials(label)}
      </AvatarFallback>
    </Avatar>
  );
}
