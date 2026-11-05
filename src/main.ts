import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module.js';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  await app.listen(process.env.PORT ?? 3000);
   console.log(`Application running on port ${process.env.PORT ?? 3000}`);

  // ========================================================
  // SIMULACIÓN DE FALLO PARA PROBAR ECS CIRCUIT BREAKER
  // ========================================================
  console.error('💥 ERROR FATAL: Fallo simulado en el arranque de la aplicación');
  process.exit(1);
}
await bootstrap();
