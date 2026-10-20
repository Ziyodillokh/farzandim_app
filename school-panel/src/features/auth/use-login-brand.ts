'use client';

import { useQuery } from '@tanstack/react-query';
import { useEffect, useState } from 'react';

import { fetchPublicBrand, type PublicBrand } from '@/data/http/public-brand';
import { initialSchoolCode } from '@/data/http/session';
import { isHttpMode } from '@/data/source';
import { useSchool } from '@/features/school/hooks';

const BRAND_STALE_MS = 5 * 60_000;

/** `undefined` — yuklanmoqda, `null` — maktab noma'lum (brend chipi ko'rsatilmaydi). */
type LoginBrand = PublicBrand | null | undefined;

function useMockBrand(): LoginBrand {
  return useSchool().data?.school;
}

/** Sessiyasiz: maktab kodi URL'dan yoki oxirgi kirishdan, brend ochiq API'dan. */
function useHttpBrand(): LoginBrand {
  const [code, setCode] = useState<string | null>(null);
  useEffect(() => setCode(initialSchoolCode()), []);
  const query = useQuery({
    queryKey: ['public-brand', code],
    queryFn: () => fetchPublicBrand(code ?? ''),
    enabled: Boolean(code),
    staleTime: BRAND_STALE_MS,
    retry: false,
  });
  if (code === '') return null;
  return query.data;
}

/** Kirish sahifasidagi maktab brendi (rejim build vaqtida aniqlanadi). */
export const useLoginBrand: () => LoginBrand = isHttpMode ? useHttpBrand : useMockBrand;
