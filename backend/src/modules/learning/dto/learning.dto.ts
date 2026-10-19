import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  ArrayUnique,
  IsArray,
  IsIn,
  IsInt,
  IsDate,
  IsOptional,
  IsUUID,
  Max,
  Min,
} from 'class-validator';
import {
  API_SUBJECTS,
  ApiSubject,
  MAX_GRADE,
  MAX_SUBJECTS,
  MIN_GRADE,
  MIN_SUBJECTS,
} from '../domain/subjects';
import { MAX_OPTIONS } from '../domain/question-bank';

export class SaveLearningProfileDto {
  @ApiProperty({ minimum: MIN_GRADE, maximum: MAX_GRADE, example: 7 })
  @IsInt()
  @Min(MIN_GRADE)
  @Max(MAX_GRADE)
  grade!: number;

  @ApiProperty({ enum: API_SUBJECTS, isArray: true, example: ['math', 'english'] })
  @IsArray()
  @ArrayMinSize(MIN_SUBJECTS)
  @ArrayMaxSize(MAX_SUBJECTS)
  @ArrayUnique()
  @IsIn(API_SUBJECTS, { each: true })
  subjects!: ApiSubject[];
}

export class StartAttemptDto {
  @ApiProperty({ enum: API_SUBJECTS, example: 'math' })
  @IsIn(API_SUBJECTS)
  subject!: ApiSubject;
}

export class SubmitAnswerDto {
  @ApiProperty()
  @IsUUID()
  questionId!: string;

  @ApiProperty({ minimum: 0, maximum: MAX_OPTIONS - 1 })
  @IsInt()
  @Min(0)
  @Max(MAX_OPTIONS - 1)
  selectedIndex!: number;
}

export class ListResultsQueryDto {
  @ApiPropertyOptional({ minimum: 1, maximum: 100, default: 30 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;

  @ApiPropertyOptional({ description: 'Shu vaqtdan oldingilar (kursor, ISO 8601)' })
  @IsOptional()
  @Type(() => Date)
  @IsDate()
  before?: Date;

  @ApiPropertyOptional({ enum: API_SUBJECTS })
  @IsOptional()
  @IsIn(API_SUBJECTS)
  subject?: ApiSubject;
}

export class SummaryQueryDto {
  @ApiPropertyOptional({ enum: [7, 30], default: 7 })
  @IsOptional()
  @Type(() => Number)
  @IsIn([7, 30])
  days?: 7 | 30;
}
