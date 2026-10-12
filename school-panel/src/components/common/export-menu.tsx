'use client';

import { Download, FileSpreadsheet, Printer } from 'lucide-react';

import { Button } from '@/components/ui/button';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import { useI18n } from '@/i18n';

export function ExportMenu({ onCsv, onPrint, disabled }: { onCsv?: () => void; onPrint?: () => void; disabled?: boolean }) {
  const { t } = useI18n();
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="outline" disabled={disabled}>
          <Download />
          {t('common.export')}
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        {onCsv && (
          <DropdownMenuItem onClick={onCsv}>
            <FileSpreadsheet className="h-4 w-4" />
            {t('common.exportCsv')}
          </DropdownMenuItem>
        )}
        <DropdownMenuItem onClick={onPrint ?? (() => window.print())}>
          <Printer className="h-4 w-4" />
          {t('common.print')}
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
