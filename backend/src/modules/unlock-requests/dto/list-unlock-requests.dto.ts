import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsOptional, IsString } from 'class-validator';

/** Ota-ona unlock so'rovlarini status bo'yicha filtrlaydi. */
export class ListUnlockRequestsDto {
  @ApiPropertyOptional({
    enum: ['pending', 'approved', 'denied', 'expired'],
    description: 'Status filtri (kichik harf). Berilmasa — hammasi.',
  })
  @IsOptional()
  @IsString()
  @IsIn(['pending', 'approved', 'denied', 'expired'])
  status?: string;
}
