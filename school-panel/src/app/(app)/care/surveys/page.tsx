'use client';

import { Library, ListChecks } from 'lucide-react';
import { useState } from 'react';

import { PageHeader } from '@/components/common/page-header';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { PrivacyBanner } from '@/features/care/components/privacy-banner';
import { QuestionBankTab } from '@/features/care/components/question-bank-tab';
import { SurveysTab } from '@/features/care/components/surveys-tab';
import { useI18n } from '@/i18n';

type Tab = 'surveys' | 'bank';

export default function CareSurveysPage() {
  const { t } = useI18n();
  const [tab, setTab] = useState<Tab>('surveys');

  return (
    <>
      <PageHeader title={t('care.surveys.title')} subtitle={t('care.surveys.subtitle')} backHref="/care" backLabel={t('care.title')} />
      <PrivacyBanner />
      <Tabs value={tab} onValueChange={(v) => setTab(v as Tab)}>
        <TabsList>
          <TabsTrigger value="surveys">
            <ListChecks />
            {t('care.surveys.tabSurveys')}
          </TabsTrigger>
          <TabsTrigger value="bank">
            <Library />
            {t('care.surveys.tabBank')}
          </TabsTrigger>
        </TabsList>
        <TabsContent value="surveys" className="animate-fade-in">
          <SurveysTab />
        </TabsContent>
        <TabsContent value="bank" className="animate-fade-in">
          <QuestionBankTab />
        </TabsContent>
      </Tabs>
    </>
  );
}
