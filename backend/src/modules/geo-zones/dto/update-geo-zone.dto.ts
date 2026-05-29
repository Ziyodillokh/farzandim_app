import { PartialType } from '@nestjs/swagger';
import { CreateGeoZoneDto } from './create-geo-zone.dto';

export class UpdateGeoZoneDto extends PartialType(CreateGeoZoneDto) {}
