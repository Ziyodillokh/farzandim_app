import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsInt,
  IsISO8601,
  IsString,
  IsUUID,
  Length,
  Max,
  Min,
  ValidateNested,
} from 'class-validator';
import { MAX_OPTIONS } from '../domain/question-bank';

/** Bitta to'plamda eng ko'p savollar (oddiy mashq — 10 ta). */
export const OFFLINE_MAX_QUESTIONS = 30;

export class OfflineAnswerDto {
  @ApiProperty()
  @IsUUID()
  questionId!: string;

  @ApiProperty({ minimum: 0, maximum: MAX_OPTIONS - 1 })
  @IsInt()
  @Min(0)
  @Max(MAX_OPTIONS - 1)
  selectedIndex!: number;
}

/** Oflayn bajarilgan mashq (U10): to'plam imzosi bilan; qayta yuborish — o'sha natija. */
export class OfflineAttemptDto {
  @ApiProperty({ description: 'Ilova yaratgan UUID — urinish id si (idempotent)' })
  @IsUUID('4')
  clientAttemptId!: string;

  @ApiProperty()
  @IsUUID('4')
  packId!: string;

  @ApiProperty()
  @IsISO8601()
  expiresAt!: string;

  @ApiProperty({ description: "To'plamdagi shu fan imzosi (hex)" })
  @IsString()
  @Length(64, 64)
  signature!: string;

  @ApiProperty()
  @IsString()
  @Length(1, 32)
  subject!: string;

  @ApiProperty({ type: [String] })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(OFFLINE_MAX_QUESTIONS)
  @IsUUID('all', { each: true })
  questionIds!: string[];

  @ApiProperty({ type: [OfflineAnswerDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(OFFLINE_MAX_QUESTIONS)
  @ValidateNested({ each: true })
  @Type(() => OfflineAnswerDto)
  answers!: OfflineAnswerDto[];

  @ApiProperty()
  @IsISO8601()
  completedAt!: string;
}
