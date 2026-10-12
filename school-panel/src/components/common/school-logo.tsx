import type { School } from '@/data/contracts';
import { cn, initials } from '@/lib/utils';

/** Maktab logosi (yuklangan rasm) yoki nomidan bosh harflar. */
export function SchoolLogo({ school, className }: { school: Pick<School, 'name' | 'shortName' | 'logo'> | undefined; className?: string }) {
  if (school?.logo) {
    // eslint-disable-next-line @next/next/no-img-element -- data URL, optimizatsiya kerak emas
    return <img src={school.logo} alt={school.name} className={cn('h-10 w-10 rounded-xl bg-white object-contain p-0.5', className)} />;
  }
  const label = (school?.shortName || initials(school?.name)).slice(0, 3);
  return (
    <div
      className={cn(
        'flex h-10 w-10 items-center justify-center rounded-xl bg-gradient-to-br from-amber-300 to-orange-500 font-display font-bold text-white',
        label.length > 2 ? 'text-[0.62rem] tracking-tight' : 'text-sm',
        className,
      )}
    >
      {label}
    </div>
  );
}
