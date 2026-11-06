import { ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsBoolean,
  IsOptional,
  IsString,
  Matches,
  ValidateIf,
} from 'class-validator';
import {
  DEFAULT_REMINDER_TIME,
  REMINDER_TIME_MAX,
  REMINDER_TIME_MIN,
} from '../../../common/notification-prefs/notification-prefs';

const HHMM = /^([01]\d|2[0-3]):[0-5]\d$/;

/** Eslatma sozlamalarini yangilash (qisman). */
export class UpdatePreferencesDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  studyNudge?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  healthNudge?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  contentReminder?: boolean;

  @ApiPropertyOptional({ example: '22:00', description: 'Tinch soat boshi (HH:MM) yoki null' })
  @IsOptional()
  @ValidateIf((_, v) => v !== null)
  @IsString()
  @Matches(HHMM, { message: 'quietFrom HH:MM formatida bo\'lishi kerak' })
  quietFrom?: string | null;

  @ApiPropertyOptional({ example: '08:00', description: 'Tinch soat oxiri (HH:MM) yoki null' })
  @IsOptional()
  @ValidateIf((_, v) => v !== null)
  @IsString()
  @Matches(HHMM, { message: 'quietTo HH:MM formatida bo\'lishi kerak' })
  quietTo?: string | null;

  // Men (I07). `null` ruxsat etilmaydi (faqat yo'q yoki boolean) — aks holda 400.
  @ApiPropertyOptional({ description: 'Ertangi topshiriq eslatmasi (17:00 Toshkent)' })
  @ValidateIf((_, v) => v !== undefined)
  @IsBoolean()
  homeworkReminder?: boolean;

  @ApiPropertyOptional({ description: "Maktab e'lonlari push'i" })
  @ValidateIf((_, v) => v !== undefined)
  @IsBoolean()
  schoolAnnouncements?: boolean;

  @ApiPropertyOptional({ description: 'Oila matn / ovoz xabarlari push\'i (SOS va qo\'ng\'iroqlar bundan mustasno)' })
  @ValidateIf((_, v) => v !== undefined)
  @IsBoolean()
  familyMessages?: boolean;

  @ApiPropertyOptional({ description: 'Kunlik o\'qish eslatmasi' })
  @ValidateIf((_, v) => v !== undefined)
  @IsBoolean()
  dailyReminder?: boolean;

  @ApiPropertyOptional({
    example: DEFAULT_REMINDER_TIME,
    description: `Kunlik eslatma vaqti HH:MM (Toshkent), ${REMINDER_TIME_MIN}–${REMINDER_TIME_MAX}; aks holda 400 VALIDATION`,
  })
  // Format / oraliq servisda tekshiriladi (har qanday noto'g'ri qiymat, jumladan null -> 400 VALIDATION).
  @IsOptional()
  dailyReminderTime?: string | null;

  @ApiPropertyOptional({ description: "true — push lock-screen'da neytral (mazmun va yuboruvchisiz)" })
  @ValidateIf((_, v) => v !== undefined)
  @IsBoolean()
  hideText?: boolean;
}
