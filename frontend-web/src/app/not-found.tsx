import Link from 'next/link';
import { Button } from '@/components/ui/button';

export default function NotFound() {
  return (
    <div className="container flex min-h-screen flex-col items-center justify-center gap-4 text-center">
      <h1 className="text-8xl font-bold text-primary">404</h1>
      <p className="text-xl text-muted-foreground">Sahifa topilmadi</p>
      <Button asChild>
        <Link href="/">Bosh sahifaga qaytish</Link>
      </Button>
    </div>
  );
}
