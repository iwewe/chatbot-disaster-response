import axios from 'axios';
import config from '../config/env.js';
import logger from '../utils/logger.js';

class WhatsAppService {
  constructor() {
    this.phoneNumberId = config.whatsapp.phoneNumberId;
    this.accessToken = config.whatsapp.accessToken;
    this.apiUrl = `https://graph.facebook.com/v18.0/${this.phoneNumberId}/messages`;
  }

  /**
   * Send text message
   */
  async sendMessage(to, message) {
    try {
      const response = await axios.post(
        this.apiUrl,
        {
          messaging_product: 'whatsapp',
          recipient_type: 'individual',
          to: to.replace(/\D/g, ''), // Remove non-digits
          type: 'text',
          text: {
            preview_url: false,
            body: message,
          },
        },
        {
          headers: {
            Authorization: `Bearer ${this.accessToken}`,
            'Content-Type': 'application/json',
          },
        }
      );

      logger.info('WhatsApp message sent', { to, messageId: response.data.messages?.[0]?.id });
      return { success: true, messageId: response.data.messages?.[0]?.id };
    } catch (error) {
      logger.error('Failed to send WhatsApp message', {
        to,
        error: error.response?.data || error.message,
      });
      return { success: false, error: error.message };
    }
  }

  /**
   * Send report confirmation
   */
  async sendReportConfirmation(to, report) {
    const message = this.formatReportConfirmation(report);
    return await this.sendMessage(to, message);
  }

  /**
   * Format report confirmation message
   */
  formatReportConfirmation(report) {
    const typeMap = {
      KORBAN: 'Korban (Meninggal/Hilang/Luka)',
      KEBUTUHAN: 'Kebutuhan Bantuan',
    };

    const urgencyMap = {
      CRITICAL: '🚨 KRITIS - Tindakan segera!',
      HIGH: '🔴 TINGGI - Tindakan dalam hitungan jam',
      MEDIUM: '🟡 SEDANG',
      LOW: '🟢 RENDAH',
    };

    let message = `✅ *LAPORAN DITERIMA*\n\n`;
    message += `ID Laporan: *${report.reportNumber}*\n`;
    message += `Jenis: ${typeMap[report.type] || report.type}\n`;
    message += `Tingkat Urgensi: ${urgencyMap[report.urgency]}\n`;
    message += `Lokasi: ${report.location}\n\n`;

    message += `📋 *Ringkasan:*\n${report.summary}\n\n`;

    if (report.status === 'PENDING_VERIFICATION') {
      message += `⏳ Status: Menunggu verifikasi\n`;
      message += `Tim kami akan menghubungi Anda segera untuk konfirmasi.\n\n`;
    } else {
      message += `✅ Status: Terverifikasi\n`;
      if (report.urgency === 'CRITICAL' || report.urgency === 'HIGH') {
        message += `Tim tanggap darurat telah diberitahu dan akan segera menindaklanjuti.\n\n`;
      }
    }

    message += `Mohon standby di nomor ini untuk update lebih lanjut.\n\n`;
    message += `_Waktu: ${new Date(report.createdAt).toLocaleString('id-ID')}_`;

    return message;
  }

  /**
   * Send follow-up question
   */
  async sendFollowUpQuestion(to, question, reportNumber) {
    const message = `🤖 *Pertanyaan Lanjutan*\n\nTerkait laporan #${reportNumber}:\n\n${question}\n\n_Balas pesan ini untuk melengkapi data._`;
    return await this.sendMessage(to, message);
  }

  /**
   * Send status update
   */
  async sendStatusUpdate(to, report, statusMessage) {
    let message = `📢 *UPDATE LAPORAN #${report.reportNumber}*\n\n`;
    message += `${statusMessage}\n\n`;
    message += `Lokasi: ${report.location}\n`;
    message += `_${new Date().toLocaleString('id-ID')}_`;

    return await this.sendMessage(to, message);
  }

  /**
   * Send welcome message for new users
   */
  async sendWelcomeMessage(to, isVerifiedVolunteer = false) {
    let message = `👋 Selamat datang di *Sistem Tanggap Darurat Bencana*\n\n`;

    if (isVerifiedVolunteer) {
      message += `✅ Anda terdaftar sebagai relawan terverifikasi.\n\n`;
    }

    message += `Anda dapat melaporkan:\n`;
    message += `🆘 Korban (meninggal, hilang, luka)\n`;
    message += `📦 Kebutuhan bantuan (pangan, air, medis, shelter, dll)\n\n`;

    message += `*Cara Melapor:*\n`;
    message += `Kirim pesan dengan format bebas, contoh:\n`;
    message += `"Ada 3 orang terluka di Dusun Kali RT 02, butuh evakuasi segera"\n\n`;

    message += `Sistem AI kami akan membantu mengekstrak informasi. Jika ada data yang kurang, kami akan bertanya.\n\n`;

    message += `_Pastikan nomor ini aktif untuk menerima update._`;

    return await this.sendMessage(to, message);
  }

  /**
   * Send error message
   */
  async sendErrorMessage(to, errorType = 'general') {
    const messages = {
      general: `❌ Maaf, terjadi kesalahan sistem. Tim kami telah diberitahu. Silakan coba lagi dalam beberapa menit atau hubungi admin.`,
      ai_timeout: `⏳ Maaf, sistem sedang sibuk. Laporan Anda sudah kami terima dan akan diproses segera. Mohon tunggu konfirmasi.`,
      invalid_format: `❓ Maaf, kami tidak dapat memproses pesan Anda. Pastikan Anda mengirim laporan dalam format yang jelas.\n\nContoh:\n"Ada korban luka di Desa X"\n"Butuh bantuan makanan untuk 50 orang di Posko Y"`,
    };

    const message = messages[errorType] || messages.general;
    return await this.sendMessage(to, message);
  }

  /**
   * Verify webhook (for initial setup)
   */
  verifyWebhook(mode, token, challenge) {
    if (mode === 'subscribe' && token === config.whatsapp.verifyToken) {
      logger.info('Webhook verified');
      return challenge;
    }
    return null;
  }

  /**
   * Parse incoming webhook message
   */
  parseIncomingMessage(webhookBody) {
    try {
      const entry = webhookBody.entry?.[0];
      const changes = entry?.changes?.[0];
      const value = changes?.value;

      if (!value?.messages) {
        return null;
      }

      const message = value.messages[0];
      const contact = value.contacts?.[0];

      const baseMessage = {
        messageId: message.id,
        from: message.from,
        name: contact?.profile?.name || '',
        timestamp: message.timestamp,
        type: message.type,
      };

      // Handle different message types
      switch (message.type) {
        case 'text':
          return {
            ...baseMessage,
            text: message.text.body,
          };

        case 'image':
          return {
            ...baseMessage,
            text: message.image.caption || '',
            media: {
              type: 'IMAGE',
              id: message.image.id,
              mimeType: message.image.mime_type,
              sha256: message.image.sha256,
            },
          };

        case 'video':
          return {
            ...baseMessage,
            text: message.video.caption || '',
            media: {
              type: 'VIDEO',
              id: message.video.id,
              mimeType: message.video.mime_type,
              sha256: message.video.sha256,
            },
          };

        case 'audio':
          return {
            ...baseMessage,
            text: '', // Audio doesn't have caption
            media: {
              type: 'AUDIO',
              id: message.audio.id,
              mimeType: message.audio.mime_type,
              sha256: message.audio.sha256,
            },
          };

        case 'document':
          return {
            ...baseMessage,
            text: message.document.caption || '',
            media: {
              type: 'DOCUMENT',
              id: message.document.id,
              mimeType: message.document.mime_type,
              filename: message.document.filename,
              sha256: message.document.sha256,
            },
          };

        case 'voice':
          return {
            ...baseMessage,
            text: '', // Voice note doesn't have caption
            media: {
              type: 'AUDIO',
              id: message.voice.id,
              mimeType: message.voice.mime_type,
              sha256: message.voice.sha256,
            },
          };

        default:
          logger.warn('Unsupported message type', { type: message.type });
          return null;
      }
    } catch (error) {
      logger.error('Failed to parse incoming message', { error: error.message });
      return null;
    }
  }

  /**
   * Mark message as read
   */
  async markAsRead(messageId) {
    try {
      await axios.post(
        this.apiUrl,
        {
          messaging_product: 'whatsapp',
          status: 'read',
          message_id: messageId,
        },
        {
          headers: {
            Authorization: `Bearer ${this.accessToken}`,
            'Content-Type': 'application/json',
          },
        }
      );

      logger.debug('Message marked as read', { messageId });
      return { success: true };
    } catch (error) {
      logger.error('Failed to mark message as read', { error: error.message });
      return { success: false };
    }
  }

  /**
   * Health check
   */
  async healthCheck() {
    try {
      // Try to get phone number info
      const response = await axios.get(
        `https://graph.facebook.com/v18.0/${this.phoneNumberId}`,
        {
          headers: {
            Authorization: `Bearer ${this.accessToken}`,
          },
          timeout: 5000,
        }
      );

      return {
        status: 'healthy',
        available: true,
        phoneNumber: response.data.display_phone_number,
      };
    } catch (error) {
      return {
        status: 'unhealthy',
        available: false,
        error: error.message,
      };
    }
  }
}

export default new WhatsAppService();
