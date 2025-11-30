import makeWASocket, {
  DisconnectReason,
  useMultiFileAuthState,
  makeInMemoryStore,
  downloadMediaMessage,
} from '@whiskeysockets/baileys';
import { Boom } from '@hapi/boom';
import qrcodeTerminal from 'qrcode-terminal';
import QRCode from 'qrcode';
import pino from 'pino';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import logger from '../utils/logger.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

class WhatsAppBaileysService {
  constructor() {
    this.sock = null;
    this.qr = null;
    this.isReady = false;
    this.sessionPath = path.join(__dirname, '../../baileys-session');
    this.messageHandlers = [];

    // Create session directory if not exists
    if (!fs.existsSync(this.sessionPath)) {
      fs.mkdirSync(this.sessionPath, { recursive: true });
    }

    // Pino logger for Baileys (quiet mode)
    this.pinoLogger = pino({ level: 'silent' });

    // In-memory store for better message handling
    this.store = makeInMemoryStore({ logger: this.pinoLogger });

    this.initialize();
  }

  async initialize() {
    try {
      const { state, saveCreds } = await useMultiFileAuthState(this.sessionPath);

      this.sock = makeWASocket({
        auth: state,
        printQRInTerminal: false, // We handle QR manually
        logger: this.pinoLogger,
        browser: ['Emergency Chatbot', 'Chrome', '120.0.0'],
        markOnlineOnConnect: true,
      });

      // Bind store
      this.store.bind(this.sock.ev);

      // Connection updates (QR code, connected, etc)
      this.sock.ev.on('connection.update', async (update) => {
        const { connection, lastDisconnect, qr } = update;

        if (qr) {
          this.qr = qr;
          logger.info('📱 New QR Code generated');

          // Print QR to terminal
          qrcodeTerminal.generate(qr, { small: true }, (qrCode) => {
            console.log('\n📱 Scan QR Code dengan WhatsApp Anda:\n');
            console.log(qrCode);
            console.log('\n');
          });

          // Generate QR code image (saved for API endpoint)
          try {
            const qrImagePath = path.join(this.sessionPath, 'qr-code.png');
            await QRCode.toFile(qrImagePath, qr);
            logger.info('QR code image saved', { path: qrImagePath });
          } catch (err) {
            logger.error('Failed to save QR code image', { error: err.message });
          }
        }

        if (connection === 'close') {
          const shouldReconnect =
            (lastDisconnect?.error instanceof Boom)
              ? lastDisconnect.error.output.statusCode !== DisconnectReason.loggedOut
              : true;

          logger.warn('WhatsApp Baileys connection closed', {
            shouldReconnect,
            error: lastDisconnect?.error?.message,
          });

          if (shouldReconnect) {
            setTimeout(() => this.initialize(), 5000);
          } else {
            logger.info('WhatsApp Baileys logged out. Delete session to re-authenticate.');
            this.isReady = false;
          }
        } else if (connection === 'open') {
          logger.info('✅ WhatsApp Baileys connected successfully!');
          this.isReady = true;
          this.qr = null;
        }
      });

      // Save credentials when updated
      this.sock.ev.on('creds.update', saveCreds);

      // Handle incoming messages
      this.sock.ev.on('messages.upsert', async ({ messages, type }) => {
        if (type !== 'notify') return;

        for (const msg of messages) {
          if (!msg.message || msg.key.fromMe) continue; // Skip own messages

          const parsed = await this.parseIncomingMessage(msg);
          if (parsed) {
            // Call registered message handlers
            for (const handler of this.messageHandlers) {
              try {
                await handler(parsed);
              } catch (error) {
                logger.error('Message handler error', { error: error.message });
              }
            }
          }
        }
      });

      logger.info('WhatsApp Baileys service initialized');
    } catch (error) {
      logger.error('Failed to initialize Baileys', { error: error.message });
      setTimeout(() => this.initialize(), 10000);
    }
  }

  /**
   * Register message handler
   */
  onMessage(handler) {
    this.messageHandlers.push(handler);
  }

  /**
   * Get QR code for pairing
   */
  getQRCode() {
    return this.qr;
  }

  /**
   * Check if ready
   */
  ready() {
    return this.isReady;
  }

  /**
   * Send text message
   */
  async sendMessage(to, message) {
    if (!this.isReady || !this.sock) {
      logger.warn('Baileys not ready, cannot send message');
      return { success: false, error: 'WhatsApp not connected' };
    }

    try {
      // Format phone number to JID (WhatsApp ID format)
      const jid = to.includes('@') ? to : `${to.replace(/\D/g, '')}@s.whatsapp.net`;

      const sent = await this.sock.sendMessage(jid, {
        text: message,
      });

      logger.info('WhatsApp Baileys message sent', { to: jid, messageId: sent.key.id });
      return { success: true, messageId: sent.key.id };
    } catch (error) {
      logger.error('Failed to send Baileys message', {
        to,
        error: error.message,
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
   * Format report confirmation message (same as Meta)
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
   * Send welcome message
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
   * Verify webhook (not used for Baileys, compatibility only)
   */
  verifyWebhook(mode, token, challenge) {
    logger.warn('verifyWebhook called on Baileys service - not applicable');
    return null;
  }

  /**
   * Parse incoming Baileys message to standard format
   */
  async parseIncomingMessage(msg) {
    try {
      const from = msg.key.remoteJid.replace('@s.whatsapp.net', '');
      const messageId = msg.key.id;
      const name = msg.pushName || '';
      const timestamp = msg.messageTimestamp || Math.floor(Date.now() / 1000);

      const baseMessage = {
        messageId,
        from,
        name,
        timestamp: timestamp.toString(),
        type: 'text',
      };

      // Handle text message
      if (msg.message?.conversation) {
        return {
          ...baseMessage,
          text: msg.message.conversation,
        };
      }

      if (msg.message?.extendedTextMessage) {
        return {
          ...baseMessage,
          text: msg.message.extendedTextMessage.text,
        };
      }

      // Handle image
      if (msg.message?.imageMessage) {
        const buffer = await downloadMediaMessage(msg, 'buffer', {}, { logger: this.pinoLogger });
        const caption = msg.message.imageMessage.caption || '';

        return {
          ...baseMessage,
          type: 'image',
          text: caption,
          media: {
            type: 'IMAGE',
            buffer,
            mimeType: msg.message.imageMessage.mimetype,
            caption,
          },
        };
      }

      // Handle video
      if (msg.message?.videoMessage) {
        const buffer = await downloadMediaMessage(msg, 'buffer', {}, { logger: this.pinoLogger });
        const caption = msg.message.videoMessage.caption || '';

        return {
          ...baseMessage,
          type: 'video',
          text: caption,
          media: {
            type: 'VIDEO',
            buffer,
            mimeType: msg.message.videoMessage.mimetype,
            caption,
          },
        };
      }

      // Handle document
      if (msg.message?.documentMessage) {
        const buffer = await downloadMediaMessage(msg, 'buffer', {}, { logger: this.pinoLogger });
        const filename = msg.message.documentMessage.fileName || 'document';

        return {
          ...baseMessage,
          type: 'document',
          text: '',
          media: {
            type: 'DOCUMENT',
            buffer,
            mimeType: msg.message.documentMessage.mimetype,
            filename,
          },
        };
      }

      // Handle audio/voice
      if (msg.message?.audioMessage) {
        const buffer = await downloadMediaMessage(msg, 'buffer', {}, { logger: this.pinoLogger });

        return {
          ...baseMessage,
          type: 'audio',
          text: '',
          media: {
            type: 'AUDIO',
            buffer,
            mimeType: msg.message.audioMessage.mimetype,
          },
        };
      }

      logger.debug('Unsupported message type', { message: msg.message });
      return null;
    } catch (error) {
      logger.error('Failed to parse Baileys message', { error: error.message });
      return null;
    }
  }

  /**
   * Disconnect and cleanup
   */
  async disconnect() {
    if (this.sock) {
      await this.sock.logout();
      this.isReady = false;
      logger.info('WhatsApp Baileys disconnected');
    }
  }
}

export default WhatsAppBaileysService;
