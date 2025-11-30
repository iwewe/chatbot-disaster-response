import config from '../config/env.js';
import logger from '../utils/logger.js';
import WhatsAppService from './whatsapp.service.js';
import WhatsAppBaileysService from './whatsapp-baileys.service.js';

/**
 * WhatsApp Hybrid Service
 * Uses Meta as primary, Baileys as fallback
 */
class WhatsAppHybridService {
  constructor() {
    this.metaService = new WhatsAppService();
    this.baileysService = new WhatsAppBaileysService();
    this.primaryMode = 'meta'; // meta or baileys
  }

  /**
   * Try primary service, fallback to secondary
   */
  async sendMessage(to, message) {
    const primary = this.primaryMode === 'meta' ? this.metaService : this.baileysService;
    const fallback = this.primaryMode === 'meta' ? this.baileysService : this.metaService;

    // Try primary
    const result = await primary.sendMessage(to, message);

    if (!result.success) {
      logger.warn('Primary WhatsApp service failed, trying fallback', {
        primary: this.primaryMode,
        error: result.error,
      });

      // Try fallback
      const fallbackResult = await fallback.sendMessage(to, message);

      if (fallbackResult.success) {
        logger.info('Fallback WhatsApp service succeeded', {
          fallback: this.primaryMode === 'meta' ? 'baileys' : 'meta',
        });
      }

      return fallbackResult;
    }

    return result;
  }

  async sendReportConfirmation(to, report) {
    const message = this.metaService.formatReportConfirmation(report);
    return await this.sendMessage(to, message);
  }

  async sendFollowUpQuestion(to, question, reportNumber) {
    const primary = this.primaryMode === 'meta' ? this.metaService : this.baileysService;
    return await primary.sendFollowUpQuestion(to, question, reportNumber);
  }

  async sendStatusUpdate(to, report, statusMessage) {
    const primary = this.primaryMode === 'meta' ? this.metaService : this.baileysService;
    return await primary.sendStatusUpdate(to, report, statusMessage);
  }

  async sendWelcomeMessage(to, isVerifiedVolunteer = false) {
    const primary = this.primaryMode === 'meta' ? this.metaService : this.baileysService;
    return await primary.sendWelcomeMessage(to, isVerifiedVolunteer);
  }

  async sendErrorMessage(to, errorType = 'general') {
    const primary = this.primaryMode === 'meta' ? this.metaService : this.baileysService;
    return await primary.sendErrorMessage(to, errorType);
  }

  verifyWebhook(mode, token, challenge) {
    // Only Meta uses webhook
    return this.metaService.verifyWebhook(mode, token, challenge);
  }

  parseIncomingMessage(webhookBody) {
    // Only Meta uses webhook
    return this.metaService.parseIncomingMessage(webhookBody);
  }

  /**
   * Register Baileys message handler
   */
  onBaileysMessage(handler) {
    this.baileysService.onMessage(handler);
  }

  /**
   * Get Baileys QR code
   */
  getBaileysQR() {
    return this.baileysService.getQRCode();
  }

  /**
   * Check Baileys status
   */
  isBaileysReady() {
    return this.baileysService.ready();
  }
}

/**
 * Factory to create WhatsApp service based on configuration
 */
class WhatsAppFactory {
  static createService() {
    const mode = config.whatsapp.mode || 'meta'; // 'meta', 'baileys', or 'hybrid'

    logger.info('Initializing WhatsApp service', { mode });

    switch (mode.toLowerCase()) {
      case 'baileys':
        logger.info('Using Baileys (WhatsApp Web) mode');
        return new WhatsAppBaileysService();

      case 'hybrid':
        logger.info('Using Hybrid mode (Meta primary, Baileys fallback)');
        return new WhatsAppHybridService();

      case 'meta':
      default:
        logger.info('Using Meta Cloud API mode');
        return new WhatsAppService();
    }
  }
}

export default WhatsAppFactory;
