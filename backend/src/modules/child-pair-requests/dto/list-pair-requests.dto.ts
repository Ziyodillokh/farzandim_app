import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsOptional } from 'class-validator';

export enum PairRequestStatus {
  PENDING = 'PENDING',
  APPROVED = 'APPROVED',
  REJECTED = 'REJECTED',
  EXPIRED = 'EXPIRED',
}

export class ListPairRequestsDto {
  @ApiPropertyOptional({ enum: PairRequestStatus })
  @IsEnum(PairRequestStatus)
  @IsOptional()
  status?: PairRequestStatus;
}
