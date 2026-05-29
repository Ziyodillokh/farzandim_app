import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsNotEmpty, IsString, MinLength } from 'class-validator';
import { Transform } from 'class-transformer';

export class LoginDto {
  @ApiProperty({ example: 'admin@farzandim.uz' })
  @IsEmail()
  @Transform(({ value }) => value?.trim().toLowerCase())
  email: string;

  @ApiProperty({ example: 'SecurePass123' })
  @IsString()
  @IsNotEmpty()
  @MinLength(1)
  password: string;
}
