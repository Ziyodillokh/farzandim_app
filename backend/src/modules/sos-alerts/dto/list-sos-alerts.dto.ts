import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsInt, IsOptional, Max, Min } from 'class-validator';
import { Type } from 'class-transformer';

export enum SosAlertStatus {
  ACTIVE = 'ACTIVE',
  RESOLVED = 'RESOLVED',
}

export class ListSosAlertsDto {
  @ApiPropertyOptional({ enum: SosAlertStatus })
  @IsEnum(SosAlertStatus)
  @IsOptional()
  status?: SosAlertStatus;

  @ApiPropertyOptional({ default: 100 })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(200)
  @IsOptional()
  limit?: number = 100;
}
