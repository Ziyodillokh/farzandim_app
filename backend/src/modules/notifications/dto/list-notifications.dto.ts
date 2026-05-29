import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsEnum, IsIn, IsInt, Min, Max } from 'class-validator';
import { Type } from 'class-transformer';
import { NotificationType } from './create-notification.dto';

export class ListNotificationsDto {
  @ApiPropertyOptional({ enum: NotificationType })
  @IsOptional()
  @IsEnum(NotificationType)
  type?: NotificationType;

  @ApiPropertyOptional({ enum: ['true', 'false'], description: 'Filter by read status' })
  @IsOptional()
  @IsIn(['true', 'false'])
  isRead?: 'true' | 'false';

  @ApiPropertyOptional({ default: 100, minimum: 1, maximum: 200 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(200)
  limit?: number;
}
