import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsOptional, IsString, MaxLength } from 'class-validator';
import { LOGIN_INPUT_MAX } from '../child-auth.constants';

/** `POST /children/:childId/credentials` va `POST /school/students/:studentId/credentials` tanasi. */
export class IssueChildCredentialDto {
  @ApiPropertyOptional({ example: 'aziza.k24', description: 'Birinchi berishda istalgan login (bo\'sh — taklif qilinadi)' })
  @IsOptional()
  @IsString()
  @MaxLength(LOGIN_INPUT_MAX)
  login?: string;

  @ApiPropertyOptional({ default: true, description: 'Qayta tiklashda bolaning barcha qurilmalarini chiqarish' })
  @IsOptional()
  @IsBoolean()
  signOutDevices?: boolean;
}
