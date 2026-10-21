import { useMutation, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';
import { kelajakApi } from '@/lib/api/admin.api';
import type { KelajakQuestion, Paginated } from '@/types/api.types';
import { kelajakErrorMessage } from './kelajak-errors';
import { kelajakKeys } from './kelajak-keys';
import { setActiveInList } from './list-cache';

interface ToggleVars {
  id: string;
  active: boolean;
}

/**
 * Faollikni almashtirish — optimistik: jadval darhol yangilanadi, xato
 * bo'lsa FAQAT shu qator qaytariladi (parallel almashtirilgan boshqa qatorlar
 * buzilmaydi). Nofaol qilish = yumshoq o'chirish (§6).
 */
export function useToggleKelajakActive() {
  const qc = useQueryClient();
  const setActive = (id: string, active: boolean) =>
    qc.setQueriesData<Paginated<KelajakQuestion>>({ queryKey: kelajakKeys.lists }, (old) =>
      setActiveInList(old, id, active),
    );

  return useMutation<unknown, unknown, ToggleVars>({
    mutationFn: ({ id, active }) => kelajakApi.update(id, { active }),
    onMutate: async ({ id, active }) => {
      await qc.cancelQueries({ queryKey: kelajakKeys.lists });
      setActive(id, active);
    },
    onError: (err, { id, active }) => {
      setActive(id, !active);
      toast.error(kelajakErrorMessage(err));
    },
    onSuccess: (_data, { active }) => {
      toast.success(active ? 'Savol faollashtirildi' : 'Savol nofaol qilindi');
    },
    // Statistika va detal ham yangilansin.
    onSettled: () => qc.invalidateQueries({ queryKey: kelajakKeys.all }),
  });
}
