import type { School } from '@/data/contracts';
import { cn, initials } from '@/lib/utils';

/** Maktab logosi (yuklangan rasm) yoki nomidan bosh harflar. */
export function SchoolLogo({ school, className }: { school: Pick<School, 'name' | 'shortName' | 'logo'> | undefined; className?: string }) {
  if (school?.logo) {
    // eslint-disable-next-line @next/next/no-img-element -- data URL, optimizatsiya kerak emas
    return <img src={school.logo} alt={school.name} className={cn('h-10 w-10 rounded-xl bg-white object-contain p-0.5 ring-1 ring-black/5', className)} />;
  }
  const label = (school?.shortName || initials(school?.name)).slice(0, 3);
  return (
    <div
      className={cn(
        'flex h-10 w-10 items-center justify-center rounded-xl bg-gradient-to-br from-brand-400 to-brand-800 font-display font-bold text-white shadow-[0_6px_16px_-6px_rgba(33,107,255,0.6)] ring-1 ring-inset ring-white/20',
        label.length > 2 ? 'text-[0.62rem] tracking-tight' : 'text-sm',
        className,
      )}
    >
      {label}
    </div>
  );
}
