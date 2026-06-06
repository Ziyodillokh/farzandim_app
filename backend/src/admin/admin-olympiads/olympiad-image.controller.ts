import {
  Controller,
  Get,
  Header,
  Param,
  StreamableFile,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiParam } from '@nestjs/swagger';
import { AdminOlympiadsService } from './admin-olympiads.service';

// Guardsiz, public proxy — olympiad savol rasmlarini ko'rsatadi. Kalit
// tasodifiy UUID (capability URL). Admin panel preview + bola app shu
// URL'dan to'g'ridan rasm yuklaydi (signed URL telefondan yetib bo'lmaydi).
@ApiTags('Olympiad Images')
@Controller('olympiad-images')
export class OlympiadImageController {
  constructor(private readonly service: AdminOlympiadsService) {}

  @Get(':key')
  @Header('Cache-Control', 'public, max-age=86400')
  @ApiOperation({ summary: 'Stream an olympiad question image (public proxy)' })
  @ApiParam({ name: 'key', description: 'Image key from upload response' })
  async serve(@Param('key') key: string): Promise<StreamableFile> {
    const obj = await this.service.getQuestionImage(key);
    return new StreamableFile(obj.body, { type: obj.contentType });
  }
}
