'use client';

import { Apple, Smartphone, SmartphoneNfc } from 'lucide-react';

import type { DeviceOs } from '@/data/contracts';
import { useI18n } from '@/i18n';

export function DeviceIcon({ device }: { device: DeviceOs }) {
  const { t } = useI18n();
  const Icon = device === 'IOS' ? Apple : device === 'ANDROID' ? Smartphone : SmartphoneNfc;
  return (
    <span className="inline-flex items-center gap-1.5 text-sm text-muted-foreground" title={t(`enums.device.${device}`)}>
      <Icon className={device === 'NONE' ? 'h-4 w-4 opacity-40' : 'h-4 w-4'} />
      <span className="hidden xl:inline">{t(`enums.device.${device}`)}</span>
    </span>
  );
}
