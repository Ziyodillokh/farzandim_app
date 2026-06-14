import { ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsBoolean,
  IsOptional,
  IsString,
  Matches,
  ValidateIf,
} from 'class-validator';

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
}
