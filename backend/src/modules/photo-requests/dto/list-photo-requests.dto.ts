import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsInt, IsOptional, Max, Min } from 'class-validator';
import { Type } from 'class-transformer';

export enum PhotoRequestStatus {
  PENDING = 'PENDING',
  COMPLETED = 'COMPLETED',
  DECLINED = 'DECLINED',
}

export class ListPhotoRequestsDto {
  @ApiPropertyOptional({ enum: PhotoRequestStatus })
  @IsEnum(PhotoRequestStatus)
  @IsOptional()
  status?: PhotoRequestStatus;

  @ApiPropertyOptional({ default: 100 })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(200)
  @IsOptional()
  limit?: number = 100;
}
