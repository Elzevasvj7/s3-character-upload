import { Module } from '@nestjs/common';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';
import { AwsS3Module } from './aws-s3/aws-s3.module.js';
import { ConfigModule } from './common/config/config.module.js';

@Module({
  imports: [AwsS3Module, ConfigModule],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
