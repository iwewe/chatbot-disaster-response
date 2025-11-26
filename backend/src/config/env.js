import dotenv from 'dotenv';
import { z } from 'zod';

dotenv.config();

// Environment validation schema
const envSchema = z.object({
  // Server
  NODE_ENV: z.enum(['development', 'production', 'test']).default('production'),
  PORT: z.string().default('3000'),
  API_BASE_URL: z.string().url(),

  // Database
  DATABASE_URL: z.string(),

  // Redis
  REDIS_HOST: z.string().default('redis'),
  REDIS_PORT: z.string().default('6379'),
  REDIS_PASSWORD: z.string().optional(),

  // JWT
  JWT_SECRET: z.string().min(32),
  JWT_EXPIRES_IN: z.string().default('7d'),

  // WhatsApp
  WHATSAPP_PHONE_NUMBER_ID: z.string(),
  WHATSAPP_ACCESS_TOKEN: z.string(),
  WHATSAPP_VERIFY_TOKEN: z.string(),
  WHATSAPP_BUSINESS_ACCOUNT_ID: z.string(),

  // Telegram
  TELEGRAM_BOT_TOKEN: z.string(),
  TELEGRAM_ADMIN_CHAT_ID: z.string(),

  // Ollama
  OLLAMA_BASE_URL: z.string().url().default('http://ollama:11434'),
  OLLAMA_MODEL: z.string().default('qwen2.5:7b'),
  OLLAMA_TIMEOUT: z.string().default('30000'),
  OLLAMA_FALLBACK_ENABLED: z.string().default('true'),

  // System
  AUTO_ASSIGN_CRITICAL_TO: z.string().optional(),
  AUTO_VERIFY_TRUST_LEVEL: z.string().default('3'),
  RATE_LIMIT_PER_MINUTE: z.string().default('10'),
  DATA_RETENTION_DAYS: z.string().default('180'),
  DEBUG_MODE: z.string().default('false'),
  LOG_LEVEL: z.enum(['error', 'warn', 'info', 'debug']).default('info'),
});

// Validate environment
let env;
try {
  env = envSchema.parse(process.env);
} catch (error) {
  console.error('❌ Invalid environment configuration:');
  console.error(error.errors);
  process.exit(1);
}

// Export typed configuration
export const config = {
  server: {
    env: env.NODE_ENV,
    port: parseInt(env.PORT),
    baseUrl: env.API_BASE_URL,
    isDevelopment: env.NODE_ENV === 'development',
    isProduction: env.NODE_ENV === 'production',
  },

  database: {
    url: env.DATABASE_URL,
  },

  redis: {
    host: env.REDIS_HOST,
    port: parseInt(env.REDIS_PORT),
    password: env.REDIS_PASSWORD || undefined,
  },

  jwt: {
    secret: env.JWT_SECRET,
    expiresIn: env.JWT_EXPIRES_IN,
  },

  whatsapp: {
    phoneNumberId: env.WHATSAPP_PHONE_NUMBER_ID,
    accessToken: env.WHATSAPP_ACCESS_TOKEN,
    verifyToken: env.WHATSAPP_VERIFY_TOKEN,
    businessAccountId: env.WHATSAPP_BUSINESS_ACCOUNT_ID,
  },

  telegram: {
    botToken: env.TELEGRAM_BOT_TOKEN,
    adminChatId: env.TELEGRAM_ADMIN_CHAT_ID,
  },

  ollama: {
    baseUrl: env.OLLAMA_BASE_URL,
    model: env.OLLAMA_MODEL,
    timeout: parseInt(env.OLLAMA_TIMEOUT),
    fallbackEnabled: env.OLLAMA_FALLBACK_ENABLED === 'true',
  },

  system: {
    autoAssignCriticalTo: env.AUTO_ASSIGN_CRITICAL_TO,
    autoVerifyTrustLevel: parseInt(env.AUTO_VERIFY_TRUST_LEVEL),
    rateLimitPerMinute: parseInt(env.RATE_LIMIT_PER_MINUTE),
    dataRetentionDays: parseInt(env.DATA_RETENTION_DAYS),
    debugMode: env.DEBUG_MODE === 'true',
    logLevel: env.LOG_LEVEL,
  },
};

export default config;
