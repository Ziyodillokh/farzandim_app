import { Module } from '@nestjs/common';
import { StorageModule } from '../../common/storage/storage.module';
import { CategoriesController } from './categories/categories.controller';
import { CategoriesService } from './categories/categories.service';
import { VideosController } from './videos/videos.controller';
import { VideosService } from './videos/videos.service';
import { AudiobooksController } from './audiobooks/audiobooks.controller';
import { AudiobooksService } from './audiobooks/audiobooks.service';
import { BooksController } from './books/books.controller';
import { BooksService } from './books/books.service';

@Module({
  imports: [StorageModule],
  controllers: [
    CategoriesController,
    VideosController,
    AudiobooksController,
    BooksController,
  ],
  providers: [
    CategoriesService,
    VideosService,
    AudiobooksService,
    BooksService,
  ],
})
export class AdminContentModule {}
