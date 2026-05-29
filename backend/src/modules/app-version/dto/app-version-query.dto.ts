import { ApiProperty } from '@nestjs/swagger';
import { IsEnum } from 'class-validator';

export enum AppType {
  parent = 'parent',
  child = 'child',
}

export class AppVersionQueryDto {
  @ApiProperty({ enum: AppType, description: 'App type: parent or child' })
  @IsEnum(AppType)
  app: AppType;
}
