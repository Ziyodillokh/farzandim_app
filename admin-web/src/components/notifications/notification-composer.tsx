'use client';

import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { toast } from 'sonner';
import { Check, ChevronLeft, ChevronRight, Loader2, Bell, Sparkles, Users, Baby, Crown, UsersRound } from 'lucide-react';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Label } from '@/components/ui/label';
import { Switch } from '@/components/ui/switch';
import { FileDropzone } from '@/components/common/file-dropzone';
import { notificationsApi } from '@/lib/api/admin.api';
import { getApiErrorMessage } from '@/lib/api/client';
import { cn } from '@/lib/utils';

const STEPS = ['Auditoriya', 'Mazmun', 'Yuborish'];

const TARGETS = [
  { value: 'all', label: 'Hammaga', icon: Users, desc: 'Barcha foydalanuvchilar' },
  { value: 'parents', label: 'Ota-onalar', icon: UsersRound, desc: 'Faqat ota-onalar' },
  { value: 'children', label: 'Bolalar', icon: Baby, desc: 'Faqat bolalar' },
  { value: 'premium', label: 'Premium', icon: Crown, desc: 'Premium obunachilar' },
  { value: 'age_group', label: 'Yosh guruhi', icon: Baby, desc: 'Yosh bo\'yicha' },
];

export function NotificationComposer({
  open,
  onOpenChange,
  onSuccess,
}: {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  onSuccess: () => void;
}) {
  const [step, setStep] = useState(0);
  const [targetType, setTargetType] = useState('all');
  const [ageFrom, setAgeFrom] = useState(3);
  const [ageTo, setAgeTo] = useState(12);
  const [title, setTitle] = useState('');
  const [message, setMessage] = useState('');
  const [imageFile, setImageFile] = useState<File | null>(null);
  const [deepLink, setDeepLink] = useState('');
  const [schedule, setSchedule] = useState(false);
  const [scheduledAt, setScheduledAt] = useState('');

  const reset = () => {
    setStep(0); setTargetType('all'); setAgeFrom(3); setAgeTo(12);
    setTitle(''); setMessage(''); setImageFile(null); setDeepLink('');
    setSchedule(false); setScheduledAt('');
  };

  const aiGenerate = useMutation({
    mutationFn: () => notificationsApi.aiGenerate(),
    onSuccess: (suggestions) => {
      if (suggestions[0]) {
        setTitle(suggestions[0].title);
        setMessage(suggestions[0].message);
        toast.success('AI tavsiya qo\'llandi');
      }
    },
    onError: (e) => toast.error(getApiErrorMessage(e)),
  });

  const send = useMutation({
    mutationFn: async () => {
      let imageUrl: string | undefined;
      if (imageFile) {
        const res = await notificationsApi.uploadImage(imageFile);
        imageUrl = res.url;
      }
      const filters: Record<string, unknown> = {};
      if (targetType === 'age_group') { filters.ageFrom = ageFrom; filters.ageTo = ageTo; }
      return notificationsApi.create({
        title, message, targetType, filters,
        imageUrl, deepLink: deepLink || undefined,
        scheduledAt: schedule && scheduledAt ? new Date(scheduledAt).toISOString() : undefined,
      });
    },
    onSuccess: () => {
      toast.success(schedule ? 'Rejalashtirildi' : 'Yuborildi');
      onSuccess();
      onOpenChange(false);
      reset();
    },
    onError: (e) => toast.error(getApiErrorMessage(e)),
  });

  const canNext = () => {
    if (step === 1) return title.trim().length > 0 && message.trim().length > 0;
    return true;
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-xl">
        <DialogHeader>
          <DialogTitle>Yangi bildirishnoma</DialogTitle>
        </DialogHeader>

        {/* Stepper */}
        <div className="flex items-center gap-2">
          {STEPS.map((label, i) => (
            <div key={label} className="flex flex-1 items-center gap-2">
              <div className={cn(
                'flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-xs font-bold',
                i < step ? 'bg-primary text-primary-foreground'
                  : i === step ? 'bg-primary text-primary-foreground ring-4 ring-primary/20'
                    : 'bg-muted text-muted-foreground',
              )}>
                {i < step ? <Check className="h-3.5 w-3.5" /> : i + 1}
              </div>
              <span className={cn('hidden text-xs font-medium sm:inline', i === step ? 'text-foreground' : 'text-muted-foreground')}>{label}</span>
              {i < STEPS.length - 1 && <div className="h-px flex-1 bg-border" />}
            </div>
          ))}
        </div>

        <div className="max-h-[55vh] overflow-y-auto px-0.5 py-2">
          {step === 0 && (
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              {TARGETS.map((t) => {
                const Icon = t.icon;
                const active = targetType === t.value;
                return (
                  <button
                    key={t.value}
                    type="button"
                    onClick={() => setTargetType(t.value)}
                    className={cn(
                      'flex items-start gap-3 rounded-xl border-2 p-4 text-left transition-colors',
                      active ? 'border-primary bg-primary/5' : 'border-border hover:border-primary/40',
                    )}
                  >
                    <div className={cn('flex h-9 w-9 items-center justify-center rounded-lg', active ? 'bg-primary text-primary-foreground' : 'bg-muted text-muted-foreground')}>
                      <Icon className="h-5 w-5" />
                    </div>
                    <div>
                      <p className="text-sm font-semibold">{t.label}</p>
                      <p className="text-xs text-muted-foreground">{t.desc}</p>
                    </div>
                  </button>
                );
              })}
              {targetType === 'age_group' && (
                <div className="col-span-full grid grid-cols-2 gap-4 rounded-xl bg-muted/40 p-4">
                  <div className="space-y-1.5">
                    <Label>Yosh (dan)</Label>
                    <Input type="number" min={0} max={25} value={ageFrom} onChange={(e) => setAgeFrom(+e.target.value)} />
                  </div>
                  <div className="space-y-1.5">
                    <Label>Yosh (gacha)</Label>
                    <Input type="number" min={0} max={25} value={ageTo} onChange={(e) => setAgeTo(+e.target.value)} />
                  </div>
                </div>
              )}
            </div>
          )}

          {step === 1 && (
            <div className="space-y-4">
              <div className="flex justify-end">
                <Button variant="soft" size="sm" onClick={() => aiGenerate.mutate()} disabled={aiGenerate.isPending}>
                  {aiGenerate.isPending ? <Loader2 className="h-4 w-4 animate-spin" /> : <Sparkles className="h-4 w-4" />}
                  AI tavsiya
                </Button>
              </div>
              <div className="space-y-1.5">
                <Label>Sarlavha</Label>
                <Input value={title} onChange={(e) => setTitle(e.target.value)} maxLength={120} placeholder="Yangi video!" />
              </div>
              <div className="space-y-1.5">
                <Label>Xabar matni</Label>
                <Textarea value={message} onChange={(e) => setMessage(e.target.value)} maxLength={500} placeholder="Bolangiz uchun yangi matematika darsi tayyor..." />
              </div>
              <FileDropzone
                label="Rasm (ixtiyoriy)"
                accept={{ 'image/jpeg': ['.jpg', '.jpeg'], 'image/png': ['.png'], 'image/webp': ['.webp'] }}
                maxSizeBytes={5 * 1024 * 1024}
                file={imageFile}
                onFile={setImageFile}
                preview
                hint="JPG/PNG/WebP, maks 5 MB"
              />
              <div className="space-y-1.5">
                <Label>Deep link (ixtiyoriy)</Label>
                <Input value={deepLink} onChange={(e) => setDeepLink(e.target.value)} placeholder="farzandim://videos" />
                <p className="text-xs text-muted-foreground">
                  Bola bosganda ochiladigan bo'lim: farzandim://videos ·
                  farzandim://audiobooks · farzandim://tests · farzandim://profile
                </p>
              </div>
            </div>
          )}

          {step === 2 && (
            <div className="space-y-4">
              <div className="flex items-center justify-between rounded-xl border border-border p-4">
                <div>
                  <p className="text-sm font-semibold">Rejalashtirish</p>
                  <p className="text-xs text-muted-foreground">Keyinroq yuborish uchun vaqt belgilang</p>
                </div>
                <Switch checked={schedule} onCheckedChange={setSchedule} />
              </div>
              {schedule && (
                <div className="space-y-1.5">
                  <Label>Yuborish vaqti</Label>
                  <Input type="datetime-local" value={scheduledAt} onChange={(e) => setScheduledAt(e.target.value)} />
                </div>
              )}

              {/* Preview */}
              <div className="rounded-xl border border-border bg-muted/30 p-4">
                <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">Ko&apos;rinishi</p>
                <div className="flex items-start gap-3 rounded-lg bg-card p-3 shadow-soft">
                  <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-primary/10 text-primary">
                    <Bell className="h-5 w-5" />
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="text-sm font-semibold">{title || 'Sarlavha'}</p>
                    <p className="line-clamp-2 text-xs text-muted-foreground">{message || 'Xabar matni'}</p>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>

        <div className="flex items-center justify-between border-t border-border pt-4">
          <Button variant="ghost" onClick={() => (step === 0 ? onOpenChange(false) : setStep((s) => s - 1))}>
            {step === 0 ? 'Bekor' : <><ChevronLeft className="h-4 w-4" /> Orqaga</>}
          </Button>
          {step < STEPS.length - 1 ? (
            <Button onClick={() => canNext() ? setStep((s) => s + 1) : toast.error('Sarlavha va xabar kiriting')}>
              Keyingi <ChevronRight className="h-4 w-4" />
            </Button>
          ) : (
            <Button onClick={() => send.mutate()} disabled={send.isPending}>
              {send.isPending ? <Loader2 className="h-4 w-4 animate-spin" /> : <Bell className="h-4 w-4" />}
              {schedule ? 'Rejalashtirish' : 'Yuborish'}
            </Button>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}
