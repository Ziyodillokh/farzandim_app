import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsNotEmpty,
  IsString,
  MaxLength,
  MinLength,
  Matches,
  IsArray,
  ArrayMinSize,
  ArrayMaxSize,
  IsInt,
  Min,
  Max,
  IsEnum,
  IsBoolean,
  IsOptional,
} from 'class-validator';

export enum ScheduleAction {
  BLOCK = 'BLOCK',
  ALLOW = 'ALLOW',
}

export class CreateScheduleDto {
  @ApiProperty({ example: 'Night block', maxLength: 100 })
  @IsNotEmpty()
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  name: string;

  @ApiProperty({ example: '22:00', description: 'Start time in HH:MM format' })
  @IsNotEmpty()
  @IsString()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/, { message: 'startTime must be HH:MM' })
  startTime: string;

  @ApiProperty({ example: '06:00', description: 'End time in HH:MM format' })
  @IsNotEmpty()
  @IsString()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/, { message: 'endTime must be HH:MM' })
  endTime: string;

  @ApiProperty({
    example: [1, 2, 3, 4, 5],
    description: 'ISO 8601 days of week (1=Mon ... 7=Sun)',
    type: [Number],
  })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(7)
  @IsInt({ each: true })
  @Min(1, { each: true })
  @Max(7, { each: true })
  daysOfWeek: number[];

  @ApiProperty({ enum: ScheduleAction })
  @IsEnum(ScheduleAction)
  action: ScheduleAction;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
