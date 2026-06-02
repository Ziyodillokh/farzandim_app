import type { ReactNode } from 'react';

export function PageHeader({
  eyebrow,
  title,
  count,
  actions,
}: {
  eyebrow?: string;
  title: string;
  count?: number;
  actions?: ReactNode;
}) {
  return (
    <div className="mb-6 flex flex-wrap items-end justify-between gap-4">
      <div>
        {eyebrow && <p className="text-sm text-muted-foreground">{eyebrow}</p>}
        <h2 className="text-2xl font-bold tracking-tight">
          {title}
          {count != null && <span className="ml-2 text-muted-foreground">({count})</span>}
        </h2>
      </div>
      {actions && <div className="flex items-center gap-2">{actions}</div>}
    </div>
  );
}
