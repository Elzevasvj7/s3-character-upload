
import { Test, TestingModule } from '@nestjs/testing';
import { AwsS3Service } from './aws-s3.service.js';
import { ConfigService } from '../common/config/config.service.js';

describe('AwsS3Service', () => {
  let service: AwsS3Service;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AwsS3Service,
        {
          provide: ConfigService,
          useValue: {
            aws: {
              region: 'us-east-2',
              bucket: 'test-bucket',
              profile: undefined,
              uploadProfile: undefined,
            },
          },
        },
      ],
    }).compile();

    service = module.get<AwsS3Service>(AwsS3Service);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });
});
