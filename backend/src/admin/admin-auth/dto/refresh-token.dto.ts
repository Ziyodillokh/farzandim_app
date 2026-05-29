import { ApiProperty } from '@nestjs/swagger';
import { IsOptional, IsString } from 'class-validator';

export class RefreshTokenDto {
  @ApiProperty({ description: 'Refresh token', required: false })
  @IsOptional()
  @IsString()
  refreshToken?: string;

  @ApiProperty({ description: 'Refresh token (snake_case alias)', required: false })
  @IsOptional()
  @IsString()
  refresh_token?: string;
}
