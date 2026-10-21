import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsIn,
  IsInt,
  IsObject,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  ValidateIf,
} from 'class-validator';
import { KELAJAK_AGE_GROUPS } from '../../../modules/kelajak/domain/age';
import { KELAJAK_ANSWER_TYPES, KELAJAK_CATEGORY_IDS } from '../../../modules/kelajak/domain/catalog';
import { TEXT_LIMITS } from '../../../modules/kelajak/domain/bank';

export const MAX_PAGE_LIMIT = 100;
const EXTERNAL_ID_MAX_LENGTH = 40;
const SEARCH_MAX_LENGTH = 100;
const SOURCE_MAX_LENGTH = TEXT_LIMITS.source;

/** PATCH: maydon berilmasligi mumkin, lekin `null` bo'lmaydi (faqat izohlar tozalanadi). */
const Present = () => ValidateIf((_, value: unknown) => value !== undefined);

/**
 * Yangi savol. Ichki tuzilma (`text`, `options`, `scoring`) va chegaralar
 * domen parseri (`parseKelajakQuestion`) bilan tekshiriladi — import bilan bir xil.
 */
export class CreateKelajakQuestionDto {
  @ApiPropertyOptional({
    example: 'ADMIN-0001',
    description: '^[A-Z0-9-]{3,40}$; berilmasa ADMIN-xxxxxxxx; PARVOZ- prefiksi bank uchun band',
  })
  @IsOptional()
  @IsString()
  @MaxLength(EXTERNAL_ID_MAX_LENGTH)
  externalId?: string;

  @ApiProperty({ enum: KELAJAK_CATEGORY_IDS })
  @IsIn(KELAJAK_CATEGORY_IDS)
  category!: string;

  @ApiProperty({ enum: KELAJAK_AGE_GROUPS })
  @IsIn(KELAJAK_AGE_GROUPS)
  ageGroup!: string;

  @ApiProperty({ example: { uz: 'Rasm chizish senga yoqadimi?' } })
  @IsObject()
  text!: Record<string, string>;

  @ApiProperty({ enum: KELAJAK_ANSWER_TYPES })
  @IsIn(KELAJAK_ANSWER_TYPES)
  answerType!: string;

  @ApiProperty({ type: 'array', items: { type: 'object' }, description: '[{value, label: {uz}}]; text turida []' })
  @IsArray()
  options!: unknown[];

  @ApiPropertyOptional({
    description:
      'Oq ro\'yxat: method, dimension, min, max, interpretation, direction, note, signal (wellbeing/safety: ' +
      'distress|knowledge), riasec (career_lab). career_interest uchun dimension: R|I|A|S|E|C majburiy; text turida null',
  })
  @IsOptional()
  @IsObject()
  scoring?: Record<string, unknown> | null;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  reverse?: boolean;

  @ApiPropertyOptional({ description: 'Berilmasa javob turidan: career_lab_5 va text — ixtiyoriy; text hech qachon majburiy emas' })
  @IsOptional()
  @IsBoolean()
  required?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  followUp?: string | null;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  notes?: string | null;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  reviewNote?: string | null;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  active?: boolean;
}

/**
 * Qisman tahrirlash. Javob berilgan savolda faqat `text`, `notes`,
 * `reviewNote`, `followUp`, `required`, `active` o'zgaradi (aks holda 409).
 * `null` — faqat izoh maydonlarini tozalaydi.
 */
export class UpdateKelajakQuestionDto {
  @Present() @IsIn(KELAJAK_CATEGORY_IDS) category?: string;
  @Present() @IsIn(KELAJAK_AGE_GROUPS) ageGroup?: string;
  @Present() @IsObject() text?: Record<string, string>;
  @Present() @IsIn(KELAJAK_ANSWER_TYPES) answerType?: string;
  @Present() @IsArray() options?: unknown[];
  @IsOptional() @IsObject() scoring?: Record<string, unknown> | null;
  @Present() @IsBoolean() reverse?: boolean;
  @Present() @IsBoolean() required?: boolean;
  @IsOptional() @IsString() followUp?: string | null;
  @IsOptional() @IsString() notes?: string | null;
  @IsOptional() @IsString() reviewNote?: string | null;
  @Present() @IsBoolean() active?: boolean;
}

export class ListKelajakQuestionsQueryDto {
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page?: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(MAX_PAGE_LIMIT) limit?: number;
  @IsOptional() @IsIn(KELAJAK_CATEGORY_IDS) category?: string;
  @IsOptional() @IsIn(KELAJAK_AGE_GROUPS) ageGroup?: string;
  // Query satri: `@Type(() => Boolean)` "false"ni ham true qiladi — shuning uchun satr.
  @IsOptional() @IsIn(['true', 'false']) active?: 'true' | 'false';
  @IsOptional() @IsIn(KELAJAK_ANSWER_TYPES) answerType?: string;
  @IsOptional() @IsString() @MaxLength(SOURCE_MAX_LENGTH) sourceType?: string;
  @IsOptional() @IsString() @MaxLength(SEARCH_MAX_LENGTH) q?: string;
}
