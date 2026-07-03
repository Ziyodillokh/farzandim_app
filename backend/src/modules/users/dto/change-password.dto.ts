import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsNotEmpty, MinLength, MaxLength } from 'class-validator';

export class ChangePasswordDto {
  @ApiProperty({ example: 'oldPass123', description: 'Joriy (eski) parol' })
  @IsString()
  @IsNotEmpty()
  oldPassword!: string;

  @ApiProperty({
    example: 'newPass123',
    description: 'Yangi parol (6-72 belgi)',
  })
  @IsString()
  @MinLength(6)
  @MaxLength(72)
  newPassword!: string;
}
