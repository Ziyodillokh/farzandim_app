import { Card } from '@/components/ui/card';
import { Sparkles } from 'lucide-react';

export function ComingSoon({ title, description }: { title: string; description?: string }) {
  return (
    <div className="container mx-auto max-w-screen-2xl px-6 py-8">
      <Card className="mx-auto flex max-w-2xl flex-col items-center gap-4 p-12 text-center">
        <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-gradient-to-br from-primary to-primary-glow">
          <Sparkles className="h-8 w-8 text-primary-foreground" />
        </div>
        <h2 className="text-2xl font-bold tracking-tight">{title}</h2>
        <p className="max-w-sm text-sm text-muted-foreground">
          {description ?? '2-bosqichda bu sahifa to\'liq tayyor bo\'ladi. Backend endpointlari allaqachon ishlaydi.'}
        </p>
      </Card>
    </div>
  );
}
