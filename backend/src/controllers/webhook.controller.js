import whatsappService from '../services/whatsapp.service.js';
import messageProcessorService from '../services/message-processor.service.js';
import logger from '../utils/logger.js';

/**
 * Verify WhatsApp webhook (GET request from Meta)
 */
export async function verifyWebhook(req, res) {
  try {
    const mode = req.query['hub.mode'];
    const token = req.query['hub.verify_token'];
    const challenge = req.query['hub.challenge'];

    const verificationResult = whatsappService.verifyWebhook(mode, token, challenge);

    if (verificationResult) {
      return res.status(200).send(verificationResult);
    }

    return res.status(403).send('Forbidden');
  } catch (error) {
    logger.error('Webhook verification failed', { error: error.message });
    return res.status(500).send('Internal Server Error');
  }
}

/**
 * Handle incoming WhatsApp message (POST request from Meta)
 */
export async function handleWebhook(req, res) {
  try {
    // Immediately respond 200 OK to prevent timeout
    res.status(200).send('OK');

    // Process message asynchronously
    const incomingMessage = whatsappService.parseIncomingMessage(req.body);

    if (!incomingMessage) {
      logger.warn('No message to process in webhook');
      return;
    }

    logger.info('Incoming message received', {
      from: incomingMessage.from,
      messageId: incomingMessage.messageId,
    });

    // Process message (non-blocking)
    messageProcessorService.processMessage(incomingMessage).catch((error) => {
      logger.error('Message processing failed', { error: error.message });
    });
  } catch (error) {
    logger.error('Webhook handler error', { error: error.message });
    // Don't send error response - already sent 200 OK
  }
}
