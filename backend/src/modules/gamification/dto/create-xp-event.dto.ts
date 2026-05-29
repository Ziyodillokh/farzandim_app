import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  IsObject,
  Max,
  Min,
  MaxLength,
} from 'class-validator';

export enum XpEventType {
  BOOK_READ = 'BOOK_READ',
  CONTEST_JOIN = 'CONTEST_JOIN',
  CONTEST_WIN = 'CONTEST_WIN',
  CREATIVE_JOIN = 'CREATIVE_JOIN',
  CREATIVE_WIN = 'CREATIVE_WIN',
  COURSE_LESSON = 'COURSE_LESSON',
  DAILY_GOAL = 'DAILY_GOAL',
  STREAK_WEEKLY = 'STREAK_WEEKLY',
  CONTENT_POST = 'CONTENT_POST',
  OTHER = 'OTHER',
}

/** Server-side max XP delta per event type. */
export const MAX_XP_DELTA: Record<XpEventType, number> = {
  [XpEventType.BOOK_READ]: 50,
  [XpEventType.CONTEST_JOIN]: 30,
  [XpEventType.CONTEST_WIN]: 200,
  [XpEventType.CREATIVE_JOIN]: 30,
  [XpEventType.CREATIVE_WIN]: 200,
  [XpEventType.COURSE_LESSON]: 40,
  [XpEventType.DAILY_GOAL]: 100,
  [XpEventType.STREAK_WEEKLY]: 150,
  [XpEventType.CONTENT_POST]: 50,
  [XpEventType.OTHER]: 50,
};

export class CreateXpEventDto {
  @ApiProperty({ enum: XpEventType })
  @IsEnum(XpEventType)
  type: XpEventType;

  @ApiProperty({ example: 30 })
  @IsInt()
  @Min(-1000)
  @Max(10000)
  xpDelta: number;

  @ApiPropertyOptional({ example: 0 })
  @IsInt()
  @Min(-1000)
  @Max(10000)
  @IsOptional()
  donDelta?: number = 0;

  @ApiPropertyOptional()
  @IsString()
  @MaxLength(200)
  @IsOptional()
  relatedId?: string;

  @ApiPropertyOptional()
  @IsObject()
  @IsOptional()
  source?: Record<string, unknown>;
}
