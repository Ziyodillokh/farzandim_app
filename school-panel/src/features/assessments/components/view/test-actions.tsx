'use client';

import { Archive, Copy, FileJson, MoreHorizontal, Rocket, Send } from 'lucide-react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useState } from 'react';

import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { Button } from '@/components/ui/button';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuSeparator, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import type { PsychTestDetail } from '@/data/mock/services/assessments';
import { useI18n } from '@/i18n';
import { useArchiveTest, useDuplicateTest, useExportTest, usePublishTest } from '../../hooks';
import { isAssignable, viewHref } from '../test-card';

type Pending = 'publish' | 'archive' | null;

/** Sarlavhadagi amallar: tayinlash, nashr/arxiv, nusxa, JSON eksport. */
export function TestActions({ test }: { test: PsychTestDetail }) {
  const { t } = useI18n();
  const router = useRouter();
  const publish = usePublishTest();
  const archive = useArchiveTest();
  const duplicate = useDuplicateTest();
  const exportTest = useExportTest();
  const [pending, setPending] = useState<Pending>(null);
  const canPublish = test.status !== 'PUBLISHED' && (test.itemCount > 0 || test.source === 'EXTERNAL');
  const canArchive = test.status !== 'ARCHIVED';

  const confirm = () => {
    const done = { onSuccess: () => setPending(null) };
    if (pending === 'publish') publish.mutate(test.id, done);
    else if (pending === 'archive') archive.mutate(test.id, done);
  };

  return (
    <>
      {isAssignable(test) && (
        <Button asChild>
          <Link href={`/assessments?assign=${encodeURIComponent(test.id)}`} data-testid="view-assign">
            <Send />
            {t('assessments.library.assign')}
          </Link>
        </Button>
      )}
      {canPublish && (
        <Button variant={isAssignable(test) ? 'outline' : 'default'} onClick={() => setPending('publish')}>
          <Rocket />
          {test.status === 'ARCHIVED' ? t('assessments.view.restore') : t('assessments.view.publish')}
        </Button>
      )}
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="outline" size="icon" aria-label={t('assessments.library.more')}>
            <MoreHorizontal />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem onClick={() => duplicate.mutate(test.id, { onSuccess: (copy) => router.push(viewHref(copy.id, 'items')) })}>
            <Copy className="h-4 w-4" />
            {t('assessments.library.duplicate')}
          </DropdownMenuItem>
          <DropdownMenuItem onClick={() => exportTest.mutate(test.id)}>
            <FileJson className="h-4 w-4" />
            {t('assessments.library.exportJson')}
          </DropdownMenuItem>
          {canArchive && (
            <>
              <DropdownMenuSeparator />
              <DropdownMenuItem onClick={() => setPending('archive')}>
                <Archive className="h-4 w-4" />
                {t('assessments.view.archive')}
              </DropdownMenuItem>
            </>
          )}
        </DropdownMenuContent>
      </DropdownMenu>
      <ConfirmDialog
        open={pending !== null}
        onOpenChange={(open) => !open && setPending(null)}
        title={pending === 'archive' ? t('assessments.view.archiveTitle') : t('assessments.view.publishTitle')}
        description={pending === 'archive' ? t('assessments.view.archiveDescription') : t('assessments.view.publishDescription')}
        confirmLabel={pending === 'archive' ? t('assessments.view.archive') : t('assessments.view.publish')}
        loading={publish.isPending || archive.isPending}
        onConfirm={confirm}
      />
    </>
  );
}
