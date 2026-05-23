import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../../generated/prisma/client';

/**
 * PrismaService — encapsula o PrismaClient com o driver adapter do Postgres.
 *
 * O backend conecta com role `service_role` do Supabase, o que **bypassa RLS**.
 * A segurança contra acesso indevido é responsabilidade dos Guards/Interceptors
 * do NestJS. Apps mobile, por outro lado, falam direto com o Supabase via SDK e
 * passam por RLS — esse é o ponto onde RLS protege os dados clínicos.
 */
@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  private readonly logger = new Logger(PrismaService.name);

  constructor(config: ConfigService) {
    const databaseUrl = config.getOrThrow<string>('DATABASE_URL');
    super({
      adapter: new PrismaPg({ connectionString: databaseUrl }),
    });
  }

  async onModuleInit(): Promise<void> {
    await this.$connect();
    this.logger.log('Prisma conectado ao Postgres (driver adapter pg)');
  }

  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
  }
}
