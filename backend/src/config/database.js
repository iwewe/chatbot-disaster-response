import { PrismaClient } from '@prisma/client';
import logger from '../utils/logger.js';

const prisma = new PrismaClient({
  log: [
    { emit: 'event', level: 'query' },
    { emit: 'event', level: 'error' },
    { emit: 'event', level: 'warn' },
  ],
});

// Log queries in debug mode
if (process.env.DEBUG_MODE === 'true') {
  prisma.$on('query', (e) => {
    logger.debug('Query:', { query: e.query, params: e.params, duration: e.duration });
  });
}

// Log errors
prisma.$on('error', (e) => {
  logger.error('Database error:', { message: e.message, target: e.target });
});

// Log warnings
prisma.$on('warn', (e) => {
  logger.warn('Database warning:', { message: e.message });
});

// Graceful shutdown
process.on('SIGINT', async () => {
  await prisma.$disconnect();
  logger.info('Database disconnected');
  process.exit(0);
});

process.on('SIGTERM', async () => {
  await prisma.$disconnect();
  logger.info('Database disconnected');
  process.exit(0);
});

export default prisma;
