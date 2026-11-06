import { ApiProperty } from '@nestjs/swagger';
import { IsIn, IsString, MaxLength, MinLength } from 'class-validator';
import { LOGIN_INPUT_MAX } from '../child-auth.constants';

export const RECOVERY_CHANNELS = ['PARENT', 'SCHOOL'] as const;
export type RecoveryChannel = (typeof RECOVERY_CHANNELS)[number];

export class ChildRecoveryRequestDto {
  @ApiProperty({ example: 'aziza.k24', maxLength: LOGIN_INPUT_MAX })
  @IsString()
  @MinLength(1)
  @MaxLength(LOGIN_INPUT_MAX)
  login!: string;

  @ApiProperty({ enum: RECOVERY_CHANNELS })
  @IsIn(RECOVERY_CHANNELS)
  channel!: RecoveryChannel;
}
