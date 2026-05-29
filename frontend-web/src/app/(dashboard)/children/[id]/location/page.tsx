'use client';

import { use } from 'react';
import Link from 'next/link';
import { useQuery } from '@tanstack/react-query';
import { ArrowLeft, Battery, Wifi, Clock, MapPin } from 'lucide-react';
import { Card } from '@/components/ui/card';
import { api } from '@/lib/api/client';
import type { Child, Location } from '@/types/api.types';

interface LocationResponse {
  location: Location;
  child: Pick<Child, 'id' | 'name' | 'batteryLevel' | 'isCharging' | 'lastSeenAt'>;
}

/**
 * Location map screen — Flutter `location_map_screen.dart` ekvivalenti.
 *
 * Production'da Google Maps qo'shamiz (react-google-maps/api).
 * Hozircha: oxirgi koordinata + ma'lumotlar.
 */
export default function LocationPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);

  const { data, isLoading, error } = useQuery({
    queryKey: ['location', id],
    queryFn: () => api.get<LocationResponse>(`/children/${id}/location`),
    refetchInterval: 30_000, // har 30 sekundda yangilanadi
  });

  return (
    <div className="container max-w-4xl py-6">
      <Link
        href="/dashboard"
        className="mb-4 inline-flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground"
      >
        <ArrowLeft className="h-4 w-4" />
        Orqaga
      </Link>

      <h1 className="mb-1 text-2xl font-bold">Joylashuv</h1>
      <p className="mb-6 text-sm text-muted-foreground">
        {data?.child.name && `${data.child.name} — oxirgi joylashuv`}
      </p>

      {isLoading && (
        <Card className="h-96 animate-pulse" />
      )}

      {error && (
        <Card className="p-10 text-center text-muted-foreground">
          Joylashuv ma&apos;lumotlari hali mavjud emas
        </Card>
      )}

      {data && (
        <>
          {/* Map placeholder — production'da Google Maps */}
          <Card className="relative mb-6 h-96 overflow-hidden bg-gradient-to-br from-secondary to-card">
            <div className="absolute inset-0 flex items-center justify-center">
              <div className="text-center">
                <MapPin className="mx-auto mb-2 h-12 w-12 text-primary" />
                <p className="font-mono text-sm">
                  {data.location.latitude.toFixed(6)}, {data.location.longitude.toFixed(6)}
                </p>
                <p className="mt-2 text-xs text-muted-foreground">
                  Google Maps integratsiyasi keyingi bosqichda
                </p>
              </div>
            </div>
          </Card>

          {/* Info row */}
          <div className="grid grid-cols-1 gap-3 md:grid-cols-3">
            <InfoCard
              icon={<Battery className="h-5 w-5" />}
              label="Batareya"
              value={
                data.child.batteryLevel != null
                  ? `${data.child.batteryLevel}%${data.child.isCharging ? ' ⚡' : ''}`
                  : '—'
              }
            />
            <InfoCard
              icon={<Clock className="h-5 w-5" />}
              label="Oxirgi faollik"
              value={
                data.child.lastSeenAt
                  ? new Date(data.child.lastSeenAt).toLocaleString('uz-UZ')
                  : '—'
              }
            />
            <InfoCard
              icon={<Wifi className="h-5 w-5" />}
              label="Aniqlik"
              value={
                data.location.accuracy != null
                  ? `${Math.round(data.location.accuracy)} m`
                  : '—'
              }
            />
          </div>
        </>
      )}
    </div>
  );
}

function InfoCard({
  icon,
  label,
  value,
}: {
  icon: React.ReactNode;
  label: string;
  value: string;
}) {
  return (
    <Card className="p-4">
      <div className="mb-2 flex items-center gap-2 text-muted-foreground">
        {icon}
        <span className="text-xs">{label}</span>
      </div>
      <div className="font-semibold">{value}</div>
    </Card>
  );
}
