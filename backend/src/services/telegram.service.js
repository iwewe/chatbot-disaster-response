import TelegramBot from 'node-telegram-bot-api';
import config from '../config/env.js';
import logger from '../utils/logger.js';

class TelegramService {
  constructor() {
    this.bot = null;
    this.adminChatId = config.telegram.adminChatId;
    this.initialize();
  }

  initialize() {
    try {
      this.bot = new TelegramBot(config.telegram.botToken, { polling: false });
      logger.info('Telegram bot initialized');
    } catch (error) {
      logger.error('Failed to initialize Telegram bot', { error: error.message });
    }
  }

  /**
   * Send alert to admin chat
   */
  async sendAlert(message, options = {}) {
    if (!this.bot) {
      logger.warn('Telegram bot not initialized, skipping alert');
      return { success: false, error: 'Bot not initialized' };
    }

    try {
      const formattedMessage = this.formatMessage(message, options);

      await this.bot.sendMessage(this.adminChatId, formattedMessage, {
        parse_mode: 'HTML',
        disable_web_page_preview: true,
        ...options.telegramOptions,
      });

      logger.info('Telegram alert sent', { chatId: this.adminChatId });
      return { success: true };
    } catch (error) {
      logger.error('Failed to send Telegram alert', { error: error.message });
      return { success: false, error: error.message };
    }
  }

  /**
   * Send new report notification
   */
  async notifyNewReport(report, reporter) {
    const icon = this.getReportIcon(report);
    const urgencyIcon = this.getUrgencyIcon(report.urgency);

    const message = `${icon} <b>LAPORAN BARU ${urgencyIcon}</b>

<b>ID:</b> ${report.reportNumber}
<b>Jenis:</b> ${this.translateReportType(report.type)}
<b>Urgensi:</b> ${this.translateUrgency(report.urgency)}

<b>Pelapor:</b> ${reporter.name || reporter.phoneNumber}
${reporter.role !== 'VOLUNTEER' ? '⚠️ <i>Pelapor bukan relawan terverifikasi</i>' : '✅ <i>Relawan terverifikasi</i>'}

<b>Lokasi:</b> ${report.location}
${report.locationDetail ? `<i>${report.locationDetail}</i>` : ''}

<b>Ringkasan:</b>
${report.summary}

<b>Status:</b> ${this.translateStatus(report.status)}

<i>Waktu: ${new Date(report.createdAt).toLocaleString('id-ID')}</i>`;

    return await this.sendAlert(message, {
      priority: report.urgency === 'CRITICAL' ? 'high' : 'normal',
    });
  }

  /**
   * Send verification reminder
   */
  async notifyVerificationNeeded(report) {
    const message = `⏳ <b>PERLU VERIFIKASI</b>

<b>ID:</b> ${report.reportNumber}
<b>Jenis:</b> ${this.translateReportType(report.type)}
<b>Lokasi:</b> ${report.location}

<b>Pelapor:</b> ${report.reporterPhone}
<i>Trust Level: ${report.reporter?.trustLevel || 0}</i>

<b>Ringkasan:</b>
${report.summary}

📞 <b>Tindakan:</b> Hubungi pelapor untuk verifikasi.`;

    return await this.sendAlert(message);
  }

  /**
   * Send critical alert (high priority)
   */
  async notifyCriticalReport(report) {
    const message = `🚨🚨🚨 <b>LAPORAN KRITIS!</b> 🚨🚨🚨

<b>ID:</b> ${report.reportNumber}
<b>Jenis:</b> ${this.translateReportType(report.type)}
<b>Lokasi:</b> ${report.location}

<b>Ringkasan:</b>
${report.summary}

⚡ <b>MEMERLUKAN TINDAKAN SEGERA!</b>

<i>Waktu: ${new Date(report.createdAt).toLocaleString('id-ID')}</i>`;

    return await this.sendAlert(message, { priority: 'critical' });
  }

  /**
   * Send system health alert
   */
  async notifySystemHealth(service, status, error = null) {
    const icon = status === 'healthy' ? '✅' : '❌';

    const message = `${icon} <b>System Health Alert</b>

<b>Service:</b> ${service}
<b>Status:</b> ${status}
${error ? `<b>Error:</b> ${error}` : ''}

<i>Time: ${new Date().toLocaleString('id-ID')}</i>`;

    return await this.sendAlert(message);
  }

  /**
   * Format message with optional enhancements
   */
  formatMessage(message, options = {}) {
    let formatted = message;

    // Add priority indicator
    if (options.priority === 'critical') {
      formatted = `🚨🚨🚨\n${formatted}\n🚨🚨🚨`;
    } else if (options.priority === 'high') {
      formatted = `🔴\n${formatted}`;
    }

    return formatted;
  }

  /**
   * Get icon for report type
   */
  getReportIcon(report) {
    const icons = {
      KORBAN: '🆘',
      KEBUTUHAN: '📦',
      PENYALURAN: '🚚',
      PENGUNGSIAN: '🏕️',
      INFRASTRUKTUR: '🏗️',
    };
    return icons[report.type] || '📋';
  }

  /**
   * Get icon for urgency level
   */
  getUrgencyIcon(urgency) {
    const icons = {
      CRITICAL: '🚨',
      HIGH: '🔴',
      MEDIUM: '🟡',
      LOW: '🟢',
    };
    return icons[urgency] || '⚪';
  }

  /**
   * Translate report type to Indonesian
   */
  translateReportType(type) {
    const translations = {
      KORBAN: 'Korban (Meninggal/Hilang/Luka)',
      KEBUTUHAN: 'Kebutuhan Bantuan',
      PENYALURAN: 'Penyaluran Bantuan',
      PENGUNGSIAN: 'Pengungsian',
      INFRASTRUKTUR: 'Kerusakan Infrastruktur',
    };
    return translations[type] || type;
  }

  /**
   * Translate urgency to Indonesian
   */
  translateUrgency(urgency) {
    const translations = {
      CRITICAL: 'Kritis (Segera!)',
      HIGH: 'Tinggi',
      MEDIUM: 'Sedang',
      LOW: 'Rendah',
    };
    return translations[urgency] || urgency;
  }

  /**
   * Translate status to Indonesian
   */
  translateStatus(status) {
    const translations = {
      PENDING_VERIFICATION: 'Menunggu Verifikasi',
      VERIFIED: 'Terverifikasi',
      ASSIGNED: 'Sudah Ditugaskan',
      IN_PROGRESS: 'Sedang Ditangani',
      RESOLVED: 'Selesai',
      CLOSED: 'Ditutup',
      STALE: 'Kadaluarsa',
    };
    return translations[status] || status;
  }

  /**
   * Health check
   */
  async healthCheck() {
    if (!this.bot) {
      return { status: 'unhealthy', available: false };
    }

    try {
      await this.bot.getMe();
      return { status: 'healthy', available: true };
    } catch (error) {
      return { status: 'unhealthy', available: false, error: error.message };
    }
  }
}

export default new TelegramService();
