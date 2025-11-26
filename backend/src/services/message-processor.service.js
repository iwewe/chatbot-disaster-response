import prisma from '../config/database.js';
import ollamaService from './ollama.service.js';
import whatsappService from './whatsapp.service.js';
import telegramService from './telegram.service.js';
import logger from '../utils/logger.js';
import config from '../config/env.js';

class MessageProcessorService {
  /**
   * Process incoming WhatsApp message
   */
  async processMessage(incomingMessage) {
    const { from, text, messageId, name } = incomingMessage;

    try {
      logger.report('Processing incoming message', { from, text: text.substring(0, 100) });

      // Mark message as read
      await whatsappService.markAsRead(messageId);

      // Get or create user
      const user = await this.getOrCreateUser(from, name);

      // Check if user is continuing a conversation
      const chatState = await this.getChatState(from);

      // Process based on chat state
      if (chatState && chatState.currentIntent) {
        return await this.handleFollowUp(user, text, chatState);
      } else {
        return await this.handleNewReport(user, text);
      }
    } catch (error) {
      logger.error('Failed to process message', { from, error: error.message });

      // Send error message to user
      await whatsappService.sendErrorMessage(from, 'general');

      // Alert admin
      await telegramService.sendAlert(
        `❌ Error processing message from ${from}:\n${error.message}`
      );

      throw error;
    }
  }

  /**
   * Handle new report (first message)
   */
  async handleNewReport(user, text) {
    try {
      // Extract data using AI
      logger.ai('Extracting report data', { userId: user.id });

      const extractionResult = await ollamaService.extractReportData(text, {
        previousReport: null,
        userTrustLevel: user.trustLevel,
      });

      if (!extractionResult.success) {
        throw new Error('Failed to extract report data');
      }

      const data = extractionResult.data;

      // Validate intent
      if (data.intent === 'unknown') {
        await whatsappService.sendErrorMessage(user.phoneNumber, 'invalid_format');
        return { success: false, reason: 'unknown_intent' };
      }

      // Check for missing critical fields
      const hasMissingCriticalFields =
        data.missingFields &&
        data.missingFields.length > 0 &&
        data.missingFields.some((f) => ['location'].includes(f));

      if (hasMissingCriticalFields) {
        // Save chat state and ask follow-up question
        await this.saveChatState(user.phoneNumber, {
          currentIntent: data.intent,
          extractedData: data,
          missingFields: data.missingFields,
        });

        const question = await ollamaService.generateFollowUpQuestion(data);
        if (question) {
          await whatsappService.sendMessage(user.phoneNumber, question);
          return { success: true, needsFollowUp: true };
        }
      }

      // Create report
      const report = await this.createReport(user, data, text);

      // Send confirmation to user
      await whatsappService.sendReportConfirmation(user.phoneNumber, report);

      // Send notifications
      await this.sendNotifications(report, user);

      // Clear chat state
      await this.clearChatState(user.phoneNumber);

      return { success: true, report };
    } catch (error) {
      logger.error('Failed to handle new report', { error: error.message });
      throw error;
    }
  }

  /**
   * Handle follow-up message (continuing conversation)
   */
  async handleFollowUp(user, text, chatState) {
    try {
      logger.ai('Handling follow-up message', { userId: user.id });

      const existingData = chatState.state.extractedData || {};

      // Try to extract missing field from this message
      const updatedData = { ...existingData };

      // Simple field mapping (for fallback)
      const missingField = chatState.state.missingFields?.[0];

      if (missingField === 'location') {
        updatedData.location = text;
        updatedData.missingFields = updatedData.missingFields.filter((f) => f !== 'location');
      }

      // Check if we have all required data now
      const stillMissing = updatedData.missingFields || [];

      if (stillMissing.length > 0) {
        // Ask next question
        await this.saveChatState(user.phoneNumber, {
          currentIntent: chatState.currentIntent,
          extractedData: updatedData,
          missingFields: stillMissing,
        });

        const question = await ollamaService.generateFollowUpQuestion(updatedData);
        if (question) {
          await whatsappService.sendMessage(user.phoneNumber, question);
        }

        return { success: true, needsFollowUp: true };
      }

      // All data collected, create report
      const fullMessage = `${chatState.state.originalMessage || ''}\n${text}`;
      const report = await this.createReport(user, updatedData, fullMessage);

      // Send confirmation
      await whatsappService.sendReportConfirmation(user.phoneNumber, report);

      // Send notifications
      await this.sendNotifications(report, user);

      // Clear chat state
      await this.clearChatState(user.phoneNumber);

      return { success: true, report };
    } catch (error) {
      logger.error('Failed to handle follow-up', { error: error.message });
      throw error;
    }
  }

  /**
   * Create report in database
   */
  async createReport(user, data, rawMessage) {
    // Determine status based on user trust level
    const status =
      user.role === 'VOLUNTEER' || user.trustLevel >= config.system.autoVerifyTrustLevel
        ? 'VERIFIED'
        : 'PENDING_VERIFICATION';

    // Generate report number
    const reportNumber = await this.generateReportNumber(
      data.intent === 'korban' ? 'KORBAN' : 'KEBUTUHAN',
      user.role === 'VOLUNTEER'
    );

    // Create report
    const report = await prisma.report.create({
      data: {
        reportNumber,
        type: data.intent === 'korban' ? 'KORBAN' : 'KEBUTUHAN',
        status,
        urgency: data.urgency?.toUpperCase() || 'MEDIUM',
        reporterId: user.id,
        reporterPhone: user.phoneNumber,
        reportSource: 'whatsapp',
        location: data.location || 'Tidak disebutkan',
        locationDetail: data.locationDetail || null,
        latitude: data.latitude || null,
        longitude: data.longitude || null,
        summary: data.summary,
        rawMessage,
        extractedData: data,
        verifiedBy: status === 'VERIFIED' ? user.id : null,
        verifiedAt: status === 'VERIFIED' ? new Date() : null,
      },
      include: {
        reporter: true,
      },
    });

    // Create person records if korban
    if (data.intent === 'korban' && data.persons && data.persons.length > 0) {
      await prisma.reportPerson.createMany({
        data: data.persons.map((person) => ({
          reportId: report.id,
          name: person.name,
          nik: person.nik || null,
          gender: person.gender || null,
          age: person.age || null,
          ageGroup: person.ageGroup || null,
          status: person.status?.toUpperCase() || 'LUKA_SEDANG',
          condition: person.condition || null,
          lastSeenLocation: person.lastSeenLocation || null,
          lastSeenDate: person.lastSeenDate ? new Date(person.lastSeenDate) : null,
          currentLocation: person.currentLocation || null,
          familyContact: person.familyContact || null,
          familyPhone: person.familyPhone || null,
          notes: person.notes || null,
        })),
      });
    }

    // Create need records if kebutuhan
    if (data.intent === 'kebutuhan' && data.needs && data.needs.length > 0) {
      await prisma.reportNeed.createMany({
        data: data.needs.map((need) => ({
          reportId: report.id,
          category: need.category?.toUpperCase() || 'LOGISTIK_LAIN',
          description: need.description,
          quantity: need.quantity || null,
          peopleAffected: need.peopleAffected || null,
          status: 'BELUM_TERPENUHI',
        })),
      });
    }

    // Create audit log
    await prisma.auditLog.create({
      data: {
        userId: user.id,
        action: 'CREATE',
        entityType: 'Report',
        entityId: report.id,
        reportId: report.id,
        metadata: {
          source: 'whatsapp',
          aiExtracted: true,
          fallback: data.fallback || false,
        },
      },
    });

    logger.report('Report created', {
      reportNumber,
      type: report.type,
      urgency: report.urgency,
      status,
    });

    return report;
  }

  /**
   * Send notifications to admin
   */
  async sendNotifications(report, user) {
    try {
      // Always send to Telegram
      if (report.urgency === 'CRITICAL') {
        await telegramService.notifyCriticalReport(report);
      } else {
        await telegramService.notifyNewReport(report, user);
      }

      // If not verified, send verification reminder
      if (report.status === 'PENDING_VERIFICATION') {
        await telegramService.notifyVerificationNeeded(report);
      }

      // Auto-assign critical reports
      if (
        report.urgency === 'CRITICAL' &&
        config.system.autoAssignCriticalTo
      ) {
        await this.autoAssignReport(report, config.system.autoAssignCriticalTo);
      }
    } catch (error) {
      logger.error('Failed to send notifications', { error: error.message });
      // Don't throw - notification failure shouldn't break report creation
    }
  }

  /**
   * Auto-assign report to volunteer
   */
  async autoAssignReport(report, phoneNumber) {
    try {
      const volunteer = await prisma.user.findUnique({
        where: { phoneNumber },
      });

      if (!volunteer) {
        logger.warn('Auto-assign failed: volunteer not found', { phoneNumber });
        return;
      }

      await prisma.report.update({
        where: { id: report.id },
        data: {
          assignedToId: volunteer.id,
          assignedAt: new Date(),
          status: 'ASSIGNED',
        },
      });

      // Notify volunteer
      await whatsappService.sendStatusUpdate(
        phoneNumber,
        report,
        `Anda ditugaskan untuk menangani laporan ini.`
      );

      logger.info('Report auto-assigned', { reportId: report.id, volunteerId: volunteer.id });
    } catch (error) {
      logger.error('Failed to auto-assign report', { error: error.message });
    }
  }

  /**
   * Generate unique report number
   */
  async generateReportNumber(type, isVerified) {
    const prefix = isVerified ? 'VR' : 'PB';
    const typePrefix = type === 'KORBAN' ? 'K' : 'N';

    // Get count of reports today
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const count = await prisma.report.count({
      where: {
        createdAt: { gte: today },
      },
    });

    const number = String(count + 1).padStart(4, '0');
    return `${prefix}-${typePrefix}-${number}`;
  }

  /**
   * Get or create user
   */
  async getOrCreateUser(phoneNumber, name = '') {
    let user = await prisma.user.findUnique({
      where: { phoneNumber },
    });

    if (!user) {
      // Create new user
      user = await prisma.user.create({
        data: {
          phoneNumber,
          name: name || phoneNumber,
          role: 'VOLUNTEER', // Default role, will be updated by admin if needed
          trustLevel: 0,
        },
      });

      logger.info('New user created', { phoneNumber, userId: user.id });

      // Send welcome message (don't await - non-blocking)
      whatsappService.sendWelcomeMessage(phoneNumber, false).catch((err) => {
        logger.error('Failed to send welcome message', { error: err.message });
      });
    }

    return user;
  }

  /**
   * Get chat state
   */
  async getChatState(phoneNumber) {
    const state = await prisma.chatState.findUnique({
      where: { phoneNumber },
    });

    // Clean up old states (> 1 hour)
    if (state) {
      const ageInMinutes = (Date.now() - new Date(state.lastMessageAt).getTime()) / 1000 / 60;
      if (ageInMinutes > 60) {
        await this.clearChatState(phoneNumber);
        return null;
      }
    }

    return state;
  }

  /**
   * Save chat state
   */
  async saveChatState(phoneNumber, state) {
    await prisma.chatState.upsert({
      where: { phoneNumber },
      update: {
        currentIntent: state.currentIntent,
        state: state,
        lastMessageAt: new Date(),
      },
      create: {
        phoneNumber,
        currentIntent: state.currentIntent,
        state: state,
      },
    });
  }

  /**
   * Clear chat state
   */
  async clearChatState(phoneNumber) {
    await prisma.chatState.delete({
      where: { phoneNumber },
    }).catch(() => {
      // Ignore error if not found
    });
  }
}

export default new MessageProcessorService();
