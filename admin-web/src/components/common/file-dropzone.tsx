'use client';

import { useEffect, useState } from 'react';
import { useDropzone, type Accept } from 'react-dropzone';
import { UploadCloud, File as FileIcon, X, CheckCircle2 } from 'lucide-react';
import { cn } from '@/lib/utils';
import { Button } from '@/components/ui/button';

function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
  return `${(bytes / 1024 / 1024 / 1024).toFixed(2)} GB`;
}

export function FileDropzone({
  label,
  accept,
  maxSizeBytes,
  file,
  onFile,
  hint,
  icon,
  preview,
}: {
  label: string;
  accept: Accept;
  maxSizeBytes: number;
  file: File | null;
  onFile: (file: File | null) => void;
  hint?: string;
  icon?: React.ReactNode;
  /** Image preview URL (for thumbnail/cover dropzones) */
  preview?: boolean;
}) {
  const { getRootProps, getInputProps, isDragActive, fileRejections } = useDropzone({
    accept,
    maxSize: maxSizeBytes,
    multiple: false,
    onDrop: (accepted) => {
      if (accepted[0]) onFile(accepted[0]);
    },
  });

  const rejection = fileRejections[0]?.errors[0];

  // Object URL'ni har render'da yaratmaymiz — aks holda har render (upload
  // progress, boshqa input o'zgarishi) yangi blob URL yaratib, eskisi hech
  // qachon revoke qilinmasdan xotira sizib ketardi. Endi faqat `file`
  // o'zgarganda yaratamiz va cleanup'da revoke qilamiz.
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  useEffect(() => {
    if (!preview || !file) {
      setPreviewUrl(null);
      return;
    }
    const url = URL.createObjectURL(file);
    setPreviewUrl(url);
    return () => URL.revokeObjectURL(url);
  }, [preview, file]);

  return (
    <div className="space-y-1.5">
      <p className="text-sm font-medium text-foreground">{label}</p>
      {file ? (
        <div className="flex items-center gap-3 rounded-lg border border-success/30 bg-success/5 p-3">
          {previewUrl ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={previewUrl} alt={file.name} className="h-12 w-12 rounded-md object-cover" />
          ) : (
            <div className="flex h-12 w-12 items-center justify-center rounded-md bg-success/10 text-success">
              <CheckCircle2 className="h-6 w-6" />
            </div>
          )}
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-medium">{file.name}</p>
            <p className="text-xs text-muted-foreground">{formatBytes(file.size)}</p>
          </div>
          <Button type="button" variant="ghost" size="icon-sm" onClick={() => onFile(null)}>
            <X className="h-4 w-4" />
          </Button>
        </div>
      ) : (
        <div
          {...getRootProps()}
          className={cn(
            'flex cursor-pointer flex-col items-center justify-center gap-2 rounded-lg border-2 border-dashed border-border bg-muted/30 px-6 py-8 text-center transition-colors',
            isDragActive && 'border-primary bg-primary/5',
            rejection && 'border-destructive/50 bg-destructive/5',
          )}
        >
          <input {...getInputProps()} />
          <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-primary/10 text-primary [&_svg]:size-6">
            {icon ?? <UploadCloud />}
          </div>
          <p className="text-sm font-medium text-foreground">
            {isDragActive ? 'Faylni shu yerga tashlang' : 'Fayl tanlang yoki sudrab tashlang'}
          </p>
          {hint && <p className="text-xs text-muted-foreground">{hint}</p>}
        </div>
      )}
      {rejection && (
        <p className="text-xs text-destructive">
          {rejection.code === 'file-too-large'
            ? `Fayl juda katta (maks ${formatBytes(maxSizeBytes)})`
            : rejection.code === 'file-invalid-type'
              ? 'Fayl formati noto‘g‘ri'
              : rejection.message}
        </p>
      )}
    </div>
  );
}

export { formatBytes };
export type { Accept };
