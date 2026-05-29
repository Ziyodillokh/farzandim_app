import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString } from 'class-validator';

export class ListInstalledAppsDto {
  @ApiPropertyOptional({ description: 'Include system apps', example: 'true' })
  @IsString()
  @IsOptional()
  includeSystem?: string;
}
