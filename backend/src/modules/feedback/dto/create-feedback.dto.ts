import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsEnum,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

export enum FeedbackEmoji {
  HAPPY = 'HAPPY',
  EXCITED = 'EXCITED',
  THINKING = 'THINKING',
  WINKING = 'WINKING',
  SAD = 'SAD',
  ANGRY = 'ANGRY',
  TIRED = 'TIRED',
  LOVE = 'LOVE',
}

export class CreateFeedbackDto {
  @ApiProperty({ enum: FeedbackEmoji })
  @IsEnum(FeedbackEmoji)
  emoji: FeedbackEmoji;

  @ApiPropertyOptional({ maxLength: 500 })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  message?: string;

  @ApiPropertyOptional({ maxLength: 100, description: 'Context where feedback was sent' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  context?: string;
}
