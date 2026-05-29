import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsNotEmpty,
  IsString,
  MaxLength,
  MinLength,
  IsEnum,
  IsOptional,
  IsObject,
} from 'class-validator';

export enum NotificationType {
  ACHIEVEMENT = 'ACHIEVEMENT',
  CONTEST = 'CONTEST',
  SCHEDULE = 'SCHEDULE',
  PARENT_REQUEST = 'PARENT_REQUEST',
  VOICE = 'VOICE',
  GEO_ZONE = 'GEO_ZONE',
  SYSTEM = 'SYSTEM',
}

export class CreateNotificationDto {
  @ApiProperty({ enum: NotificationType })
  @IsEnum(NotificationType)
  type: NotificationType;

  @ApiProperty({ example: 'Yangi yutuq!', maxLength: 200 })
  @IsNotEmpty()
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  title: string;

  @ApiProperty({ example: 'Siz 100 ball to\'pladingiz', maxLength: 1000 })
  @IsNotEmpty()
  @IsString()
  @MinLength(1)
  @MaxLength(1000)
  body: string;

  @ApiPropertyOptional({
    description: 'Additional data as key-value pairs',
    type: 'object',
    additionalProperties: true,
  })
  @IsOptional()
  @IsObject()
  data?: Record<string, unknown>;
}
