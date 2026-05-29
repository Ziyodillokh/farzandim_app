import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsInt, IsOptional, Max, Min } from 'class-validator';
import { Type } from 'class-transformer';
import { XpEventType } from './create-xp-event.dto';

export class ListXpEventsDto {
  @ApiPropertyOptional({ enum: XpEventType })
  @IsEnum(XpEventType)
  @IsOptional()
  type?: XpEventType;

  @ApiPropertyOptional({ default: 100 })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(500)
  @IsOptional()
  limit?: number = 100;
}
