import { ApiProperty } from '@nestjs/swagger';
import {
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

const TYPES = ['test', 'creative', 'mixed'] as const;
const DIFFICULTIES = ['oson', "o'rta", 'qiyin'] as const;
const STATUSES = ['draft', 'published', 'archived'] as const;
// Video/audiobook/book DTO'lari bilan bir xil — rank tizimi (free=0 < ...).
const PLAN_REQUIRED = ['free', 'standard', 'premium', 'vip'] as const;

export class QuestionDto {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  @MaxLength(2000)
  text: string;

  @ApiProperty({ type: [String] })
  @IsArray()
  @ArrayMinSize(2, { message: 'Savol kamida 2 ta variantga ega bo\'lishi shart' })
  @IsString({ each: true })
  @MaxLength(600, { each: true })
  options: string[];

  // Har variant uchun IXTIYORIY rasm kaliti — `options` bilan parallel
  // (bo'sh "" = faqat matn). Matematik formula/diagramma javoblar uchun.
  @ApiProperty({ type: [String], required: false })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @MaxLength(300, { each: true })
  optionImages?: string[];

  @ApiProperty()
  @IsInt()
  @Min(0)
  correctIndex: number;

  @ApiProperty({ default: 10 })
  @IsOptional()
  @IsInt()
  @Min(1)
  points?: number;

  // Savol rasmi kaliti (upload endpointdan qaytadi). Ixtiyoriy.
  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(300)
  imageKey?: string | null;
}

export class CreateOlympiadDto {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  @MaxLength(160)
  title: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(4000)
  description?: string | null;

  // Banner rasmi kaliti (ixtiyoriy) — question-image upload endpoint qaytargan
  // `key`. Bola dashboard test karuseli banneri.
  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  coverKey?: string | null;

  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  @MaxLength(50)
  subject: string;

  @ApiProperty()
  @IsInt()
  @Min(0)
  @Max(25)
  ageFrom: number;

  @ApiProperty()
  @IsInt()
  @Min(0)
  @Max(25)
  ageTo: number;

  @ApiProperty({ enum: TYPES, default: 'test' })
  @IsOptional()
  @IsEnum(TYPES)
  type?: (typeof TYPES)[number];

  @ApiProperty({ enum: DIFFICULTIES, default: "o'rta" })
  @IsOptional()
  @IsEnum(DIFFICULTIES)
  difficulty?: (typeof DIFFICULTIES)[number];

  @ApiProperty()
  @IsString()
  startTime: string;

  @ApiProperty()
  @IsString()
  endTime: string;

  @ApiProperty({ default: 30 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(600)
  durationMin?: number;

  @ApiProperty({ default: 50 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(10000)
  xpReward?: number;

  // Testni ko'rish uchun kerakli eng past tarif. `free` = "Barchasi" (hamma
  // ko'radi). Ixtiyoriy — berilmasa 'free'. Video/audiobook/book bilan bir xil.
  @ApiProperty({ required: false, enum: PLAN_REQUIRED, default: 'free' })
  @IsOptional()
  @IsEnum(PLAN_REQUIRED)
  planRequired?: (typeof PLAN_REQUIRED)[number];

  @ApiProperty({ required: false })
  @IsOptional()
  @IsBoolean()
  shuffleQuestions?: boolean;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsBoolean()
  shuffleAnswers?: boolean;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsBoolean()
  hideResults?: boolean;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsBoolean()
  allowBack?: boolean;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsBoolean()
  certificateEnabled?: boolean;

  @ApiProperty({ required: false, type: [QuestionDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => QuestionDto)
  questions?: QuestionDto[];

  @ApiProperty({ required: false, enum: STATUSES })
  @IsOptional()
  @IsEnum(STATUSES)
  status?: (typeof STATUSES)[number];
}
