import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../common/database/database.module';
import { TelegramSupportService } from './telegram-support.service';

/**
 * Qo'llab-quvvatlash — endi FAQAT Telegram bot (ilova ichida chat yo'q).
 * Foydalanuvchi @parvozyordambot'ga to'g'ridan yozadi; bot operatorlar
 * guruhi bilan ikki tomonlama ko'prik bo'ladi (telegram-support.service).
 *
 * Eski in-app REST qatlam (SupportController/SupportService + `/support/*`
 * endpointlari) OLIB TASHLANDI — ilovalar endi to'g'ridan-to'g'ri botga
 * havola qiladi.
 */
@Module({
  imports: [DatabaseModule],
  providers: [TelegramSupportService],
})
export class SupportModule {}
