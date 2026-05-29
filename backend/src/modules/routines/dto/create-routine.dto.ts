import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsNotEmpty,
  IsString,
  MaxLength,
  MinLength,
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

export enum RoutineType {
  SLEEP = 'SLEEP',
  SCHOOL = 'SCHOOL',
  HOMEWORK = 'HOMEWORK',
  SPORT = 'SPORT',
  OTHER = 'OTHER',
}

export class CreateRoutineDto {
  @ApiProperty({ example: 'Uxlash vaqti', maxLength: 50 })
  @IsNotEmpty()
  @IsString()
  @MinLength(1)
  @MaxLength(50)
  title: string;

  @ApiProperty({ enum: RoutineType })
  @IsEnum(RoutineType)
  type: RoutineType;

  @ApiProperty({ example: 22, minimum: 0, maximum: 23 })
  @IsInt()
  @Min(0)
  @Max(23)
  startHour: number;

  @ApiProperty({ example: 0, minimum: 0, maximum: 59 })
  @IsInt()
  @Min(0)
  @Max(59)
  startMinute: number;

  @ApiProperty({ example: 6, minimum: 0, maximum: 23 })
  @IsInt()
  @Min(0)
  @Max(23)
  endHour: number;

  @ApiProperty({ example: 30, minimum: 0, maximum: 59 })
  @IsInt()
  @Min(0)
  @Max(59)
  endMinute: number;

  @ApiProperty({
    example: [1, 2, 3, 4, 5],
    description: 'ISO 8601 weekdays (1=Mon ... 7=Sun)',
    type: [Number],
  })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(7)
  @IsInt({ each: true })
  @Min(1, { each: true })
  @Max(7, { each: true })
  weekdays: number[];

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
