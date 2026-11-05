import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { LearningTopicStatus } from '@prisma/client';
import {
  ArrayMaxSize,
  ArrayMinSize,
  ArrayUnique,
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
import { TOPIC_KEY_MAX, TOPIC_KEY_PATTERN } from '../../../modules/learning/domain/topic-input';
import { API_SUBJECTS, ApiSubject, MAX_GRADE, MIN_GRADE } from '../../../modules/learning/domain/subjects';

const TOPIC_STATUSES = Object.values(LearningTopicStatus);
/** Bir so'rovda reorder / bog'lash uchun eng ko'p element. */
const MAX_BATCH = 500;
const KEY_HINT = 'lotin kichik harf / raqam / defis (slug), masalan "oddiy-kasrlar"';

/** `title` / `goal` — `{uz, ru?, en?}`; ichki tekshiruv `parseTopicText` da. */
export class CreateLearningTopicDto {
  @ApiProperty({ enum: API_SUBJECTS })
  @IsIn(API_SUBJECTS)
  subject!: ApiSubject;

  @ApiProperty({ example: 'oddiy-kasrlar', description: KEY_HINT })
  @IsString()
  @MaxLength(TOPIC_KEY_MAX)
  @Matches(TOPIC_KEY_PATTERN, { message: `key: ${KEY_HINT}` })
  key!: string;

  @ApiProperty({ example: { uz: 'Oddiy kasrlar', ru: 'Обыкновенные дроби', en: 'Fractions' } })
  @IsObject()
  title!: Record<string, string>;

  @ApiPropertyOptional({ example: { uz: 'Kasrlarni qo\'shish va ayirish' } })
  @IsOptional()
  @IsObject()
  goal?: Record<string, string>;

  @ApiProperty({ minimum: MIN_GRADE, maximum: MAX_GRADE })
  @IsInt()
  @Min(MIN_GRADE)
  @Max(MAX_GRADE)
  minGrade!: number;

  @ApiProperty({ minimum: MIN_GRADE, maximum: MAX_GRADE })
  @IsInt()
  @Min(MIN_GRADE)
  @Max(MAX_GRADE)
  maxGrade!: number;

  @ApiPropertyOptional({ description: 'Berilmasa — fan oxiriga qo\'shiladi' })
  @IsOptional()
  @IsInt()
  @Min(0)
  position?: number;

  @ApiPropertyOptional({ enum: TOPIC_STATUSES, default: 'ACTIVE' })
  @IsOptional()
  @IsIn(TOPIC_STATUSES)
  status?: LearningTopicStatus;
}

/** `goal: null` — maqsadni o'chiradi. Fan o'zgartirilmaydi. */
export class UpdateLearningTopicDto {
  @IsOptional() @IsString() @MaxLength(TOPIC_KEY_MAX) @Matches(TOPIC_KEY_PATTERN, { message: `key: ${KEY_HINT}` }) key?: string;
  @IsOptional() @IsObject() title?: Record<string, string>;
  @IsOptional() @IsObject() goal?: Record<string, string> | null;
  @IsOptional() @IsInt() @Min(MIN_GRADE) @Max(MAX_GRADE) minGrade?: number;
  @IsOptional() @IsInt() @Min(MIN_GRADE) @Max(MAX_GRADE) maxGrade?: number;
  @IsOptional() @IsInt() @Min(0) position?: number;
  @IsOptional() @IsIn(TOPIC_STATUSES) status?: LearningTopicStatus;
}

export class ListLearningTopicsQueryDto {
  @IsOptional() @IsIn(API_SUBJECTS) subject?: ApiSubject;
  @IsOptional() @IsIn(TOPIC_STATUSES) status?: LearningTopicStatus;
}

export class ReorderLearningTopicsDto {
  @ApiProperty({ enum: API_SUBJECTS })
  @IsIn(API_SUBJECTS)
  subject!: ApiSubject;

  @ApiProperty({ description: 'Fanning BARCHA mavzulari (yashirinlari ham), yangi tartibda' })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(MAX_BATCH)
  @ArrayUnique()
  @IsUUID('all', { each: true })
  ids!: string[];
}

export class LinkTopicQuestionsDto {
  @ApiProperty({ description: 'Mavzu bilan bir fanga tegishli savollar' })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(MAX_BATCH)
  @ArrayUnique()
  @IsUUID('all', { each: true })
  questionIds!: string[];
}
