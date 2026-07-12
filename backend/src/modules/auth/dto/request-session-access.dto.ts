import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString, MaxLength } from 'class-validator';

/** "Ruxsat so'rash" — login 409 (DEVICE_LIMIT_REACHED) dan keyingi qurilma. */
export class RequestSessionAccessDto {
  @ApiProperty({ description: 'Login 409 javobidagi qisqa muddatli pendingToken' })
  @IsString()
  pendingToken: string;

  @ApiPropertyOptional({ example: 'Redmi Note 12' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  deviceModel?: string;

  @ApiPropertyOptional({ example: 'android' })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  platform?: string;
}
