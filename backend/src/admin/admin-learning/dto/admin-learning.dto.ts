import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsIn,
  IsInt,
  IsObject,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { LearningQuestionStatus } from '@prisma/client';
import { API_SUBJECTS, ApiSubject, MAX_GRADE, MIN_GRADE } from '../../../modules/learning/domain/subjects';

const STATUSES = Object.values(LearningQuestionStatus);

/** `topicId=none` — mavzuga bog'lanmagan savollar. */
export const NO_TOPIC_FILTER = 'none';
const UUID_OR_NONE = /^(none|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$/i;

/** Ichki matnlar (`{uz, ru, en}`) `parseBankQuestion` bilan tekshiriladi. */
export class LearningQuestionInputDto {
  @ApiProperty({ enum: API_SUBJECTS })
  @IsIn(API_SUBJECTS)
  subject!: ApiSubject;

  @ApiPropertyOptional({ example: 'math-22' })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  externalId?: string;

  @ApiProperty({ minimum: 1, maximum: 3 })
  @IsInt()
  difficulty!: number;

  @ApiProperty({ minimum: MIN_GRADE, maximum: MAX_GRADE })
  @IsInt()
  minGrade!: number;

  @ApiProperty({ minimum: MIN_GRADE, maximum: MAX_GRADE })
  @IsInt()
  maxGrade!: number;

  @ApiProperty({ example: { uz: 'Kasrlar', ru: 'Дроби', en: 'Fractions' } })
  @IsObject()
  topic!: Record<string, string>;

  @ApiProperty()
  @IsObject()
  prompt!: Record<string, string>;

  @ApiProperty({ type: 'array', items: { type: 'object' } })
  @IsArray()
  options!: Record<string, string>[];

  @ApiProperty()
  @IsInt()
  answerIndex!: number;

  @ApiProperty()
  @IsObject()
  explanation!: Record<string, string>;

  @ApiPropertyOptional({ enum: STATUSES })
  @IsOptional()
  @IsIn(STATUSES)
  status?: LearningQuestionStatus;

  @ApiPropertyOptional({ description: 'Mavzular katalogidagi mavzu (savol bilan bir fan)' })
  @IsOptional()
  @IsUUID()
  topicId?: string;
}

export class UpdateLearningQuestionDto {
  @IsOptional() @IsInt() difficulty?: number;
  @IsOptional() @IsInt() minGrade?: number;
  @IsOptional() @IsInt() maxGrade?: number;
  @IsOptional() @IsObject() topic?: Record<string, string>;
  @IsOptional() @IsObject() prompt?: Record<string, string>;
  @IsOptional() @IsArray() options?: Record<string, string>[];
  @IsOptional() @IsInt() answerIndex?: number;
  @IsOptional() @IsObject() explanation?: Record<string, string>;
  @IsOptional() @IsIn(STATUSES) status?: LearningQuestionStatus;
  /** `null` — mavzudan ajratadi. */
  @IsOptional() @IsUUID() topicId?: string | null;
}

export class ImportLearningQuestionsDto {
  @ApiProperty({ enum: API_SUBJECTS })
  @IsIn(API_SUBJECTS)
  subject!: ApiSubject;

  @ApiProperty({ description: 'Bank formatidagi savollar (`id`, `grades`, `question`, `answer`)' })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(500)
  questions!: unknown[];

  @ApiPropertyOptional({ enum: ['skip', 'update'], default: 'skip' })
  @IsOptional()
  @IsIn(['skip', 'update'])
  existing?: 'skip' | 'update';

  @ApiPropertyOptional({ description: 'Import qilingan (yangi va yangilangan) savollar shu mavzuga bog\'lanadi' })
  @IsOptional()
  @IsUUID()
  topicId?: string;
}

export class ListLearningQuestionsQueryDto {
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page?: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100) limit?: number;
  @IsOptional() @IsIn(API_SUBJECTS) subject?: ApiSubject;
  @IsOptional() @IsIn(STATUSES) status?: LearningQuestionStatus;
  @IsOptional() @Type(() => Number) @IsInt() @Min(MIN_GRADE) @Max(MAX_GRADE) grade?: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(3) difficulty?: number;
  @IsOptional() @IsString() @MaxLength(100) q?: string;
  /** Mavzu id'si yoki `none` (mavzusiz savollar). */
  @IsOptional() @IsString() @Matches(UUID_OR_NONE, { message: 'topicId must be a UUID or "none"' }) topicId?: string;
}
