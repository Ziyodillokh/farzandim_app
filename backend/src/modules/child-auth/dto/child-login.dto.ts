import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsDefined, IsString, MaxLength, MinLength, ValidateNested } from 'class-validator';
import { LOGIN_INPUT_MAX, PASSWORD_INPUT_MAX } from '../child-auth.constants';
import { ChildDeviceDto } from './child-device.dto';

export class ChildLoginDto {
  @ApiProperty({ example: 'aziza.k24', maxLength: LOGIN_INPUT_MAX })
  @IsString()
  @MinLength(1)
  @MaxLength(LOGIN_INPUT_MAX)
  login!: string;

  @ApiProperty({ maxLength: PASSWORD_INPUT_MAX })
  @IsString()
  @MinLength(1)
  @MaxLength(PASSWORD_INPUT_MAX)
  password!: string;

  @ApiProperty({ type: ChildDeviceDto })
  @IsDefined()
  @ValidateNested()
  @Type(() => ChildDeviceDto)
  device!: ChildDeviceDto;
}

export class ChildSetupDto {
  @ApiProperty({ description: "`SETUP_REQUIRED` javobidagi 15 daqiqalik bir martalik token" })
  @IsString()
  @MinLength(1)
  @MaxLength(2000)
  setupToken!: string;

  @ApiProperty({ maxLength: PASSWORD_INPUT_MAX })
  @IsString()
  @MinLength(1)
  @MaxLength(PASSWORD_INPUT_MAX)
  newPassword!: string;

  @ApiProperty({ type: ChildDeviceDto })
  @IsDefined()
  @ValidateNested()
  @Type(() => ChildDeviceDto)
  device!: ChildDeviceDto;
}

export class ChangeChildPasswordDto {
  @ApiProperty({ maxLength: PASSWORD_INPUT_MAX })
  @IsString()
  @MinLength(1)
  @MaxLength(PASSWORD_INPUT_MAX)
  currentPassword!: string;

  @ApiProperty({ maxLength: PASSWORD_INPUT_MAX })
  @IsString()
  @MinLength(1)
  @MaxLength(PASSWORD_INPUT_MAX)
  newPassword!: string;
}
