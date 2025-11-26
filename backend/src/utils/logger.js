import winston from 'winston';
import config from '../config/env.js';

const { combine, timestamp, printf, colorize, errors } = winston.format;

// Custom format
const customFormat = printf(({ level, message, timestamp, stack, ...meta }) => {
  let log = `${timestamp} [${level}]: ${message}`;

  // Add metadata if present
  if (Object.keys(meta).length > 0) {
    log += ` ${JSON.stringify(meta)}`;
  }

  // Add stack trace for errors
  if (stack) {
    log += `\n${stack}`;
  }

  return log;
});

// Create logger
const logger = winston.createLogger({
  level: config.system.logLevel,
  format: combine(
    errors({ stack: true }),
    timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    customFormat
  ),
  transports: [
    // Console transport
    new winston.transports.Console({
      format: combine(
        colorize(),
        customFormat
      ),
    }),

    // File transport - errors
    new winston.transports.File({
      filename: 'logs/error.log',
      level: 'error',
      maxsize: 10485760, // 10MB
      maxFiles: 5,
    }),

    // File transport - all logs
    new winston.transports.File({
      filename: 'logs/combined.log',
      maxsize: 10485760, // 10MB
      maxFiles: 5,
    }),
  ],
});

// Add emergency-specific log methods
logger.emergency = (message, meta = {}) => {
  logger.error(`🚨 EMERGENCY: ${message}`, { ...meta, emergency: true });
};

logger.critical = (message, meta = {}) => {
  logger.error(`🔴 CRITICAL: ${message}`, { ...meta, critical: true });
};

logger.report = (message, meta = {}) => {
  logger.info(`📋 REPORT: ${message}`, { ...meta, report: true });
};

logger.ai = (message, meta = {}) => {
  logger.debug(`🤖 AI: ${message}`, { ...meta, ai: true });
};

export default logger;
