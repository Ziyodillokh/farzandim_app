import Link from 'next/link';

export default function NotFound() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-4 bg-background p-6 text-center">
      <p className="font-display text-6xl font-semibold text-primary">404</p>
      <p className="text-muted-foreground">Sahifa topilmadi · Страница не найдена</p>
      <Link href="/dashboard" className="font-semibold text-primary hover:underline">
        Parvoz School
      </Link>
    </div>
  );
}
