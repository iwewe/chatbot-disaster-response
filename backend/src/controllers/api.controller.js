import prisma from '../config/database.js';
import logger from '../utils/logger.js';
import whatsappService from '../services/whatsapp.service.js';
import telegramService from '../services/telegram.service.js';

/**
 * Get all reports with filters
 */
export async function getReports(req, res) {
  try {
    const {
      type,
      status,
      urgency,
      page = 1,
      limit = 20,
      search,
      sortBy = 'createdAt',
      sortOrder = 'desc',
    } = req.query;

    const where = {};

    if (type) where.type = type;
    if (status) where.status = status;
    if (urgency) where.urgency = urgency;

    if (search) {
      where.OR = [
        { reportNumber: { contains: search, mode: 'insensitive' } },
        { location: { contains: search, mode: 'insensitive' } },
        { summary: { contains: search, mode: 'insensitive' } },
      ];
    }

    const [reports, total] = await Promise.all([
      prisma.report.findMany({
        where,
        include: {
          reporter: {
            select: { id: true, name: true, phoneNumber: true, role: true },
          },
          assignedTo: {
            select: { id: true, name: true, phoneNumber: true },
          },
          persons: true,
          needs: true,
          _count: {
            select: { actions: true },
          },
        },
        orderBy: { [sortBy]: sortOrder },
        skip: (page - 1) * limit,
        take: parseInt(limit),
      }),
      prisma.report.count({ where }),
    ]);

    res.json({
      success: true,
      data: reports,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        totalPages: Math.ceil(total / limit),
      },
    });
  } catch (error) {
    logger.error('Failed to get reports', { error: error.message });
    res.status(500).json({ success: false, error: error.message });
  }
}

/**
 * Get single report by ID
 */
export async function getReportById(req, res) {
  try {
    const { id } = req.params;

    const report = await prisma.report.findUnique({
      where: { id },
      include: {
        reporter: {
          select: { id: true, name: true, phoneNumber: true, role: true, trustLevel: true },
        },
        assignedTo: {
          select: { id: true, name: true, phoneNumber: true },
        },
        persons: true,
        needs: true,
        media: {
          orderBy: { uploadedAt: 'desc' },
        },
        actions: {
          orderBy: { createdAt: 'desc' },
        },
        auditLogs: {
          include: {
            user: {
              select: { name: true, phoneNumber: true },
            },
          },
          orderBy: { createdAt: 'desc' },
        },
      },
    });

    if (!report) {
      return res.status(404).json({ success: false, error: 'Report not found' });
    }

    res.json({ success: true, data: report });
  } catch (error) {
    logger.error('Failed to get report', { error: error.message });
    res.status(500).json({ success: false, error: error.message });
  }
}

/**
 * Update report status
 */
export async function updateReportStatus(req, res) {
  try {
    const { id } = req.params;
    const { status, notes, assignedToId } = req.body;
    const userId = req.user.id;

    const updateData = { status };

    if (status === 'VERIFIED') {
      updateData.verifiedBy = userId;
      updateData.verifiedAt = new Date();
    }

    if (status === 'RESOLVED') {
      updateData.resolvedAt = new Date();
    }

    if (assignedToId) {
      updateData.assignedToId = assignedToId;
      updateData.assignedAt = new Date();
      updateData.status = 'ASSIGNED';
    }

    const report = await prisma.report.update({
      where: { id },
      data: updateData,
      include: {
        reporter: true,
        assignedTo: true,
      },
    });

    // Create action log
    await prisma.reportAction.create({
      data: {
        reportId: id,
        type: 'STATUS_UPDATE',
        description: notes || `Status changed to ${status}`,
        takenBy: userId,
      },
    });

    // Create audit log
    await prisma.auditLog.create({
      data: {
        userId,
        action: 'UPDATE',
        entityType: 'Report',
        entityId: id,
        reportId: id,
        changes: { status: { from: report.status, to: status } },
      },
    });

    // Send notification to reporter
    if (status === 'VERIFIED' || status === 'RESOLVED') {
      const statusMessage =
        status === 'VERIFIED'
          ? 'Laporan Anda telah diverifikasi dan akan segera ditindaklanjuti.'
          : 'Laporan Anda telah selesai ditangani. Terima kasih atas laporannya.';

      await whatsappService.sendStatusUpdate(report.reporterPhone, report, statusMessage);
    }

    // Notify assigned volunteer
    if (assignedToId && report.assignedTo) {
      await whatsappService.sendStatusUpdate(
        report.assignedTo.phoneNumber,
        report,
        `Anda ditugaskan untuk menangani laporan ini. ${notes || ''}`
      );
    }

    logger.info('Report status updated', { reportId: id, status, userId });

    res.json({ success: true, data: report });
  } catch (error) {
    logger.error('Failed to update report status', { error: error.message });
    res.status(500).json({ success: false, error: error.message });
  }
}

/**
 * Get dashboard statistics
 */
export async function getDashboardStats(req, res) {
  try {
    const [
      totalReports,
      pendingVerification,
      criticalReports,
      resolvedToday,
      reportsByType,
      reportsByUrgency,
      recentReports,
    ] = await Promise.all([
      prisma.report.count(),
      prisma.report.count({ where: { status: 'PENDING_VERIFICATION' } }),
      prisma.report.count({ where: { urgency: 'CRITICAL', status: { not: 'RESOLVED' } } }),
      prisma.report.count({
        where: {
          status: 'RESOLVED',
          resolvedAt: { gte: new Date(new Date().setHours(0, 0, 0, 0)) },
        },
      }),
      prisma.report.groupBy({
        by: ['type'],
        _count: true,
      }),
      prisma.report.groupBy({
        by: ['urgency'],
        _count: true,
        where: { status: { not: 'RESOLVED' } },
      }),
      prisma.report.findMany({
        take: 10,
        orderBy: { createdAt: 'desc' },
        include: {
          reporter: {
            select: { name: true, phoneNumber: true, role: true },
          },
        },
      }),
    ]);

    res.json({
      success: true,
      data: {
        summary: {
          totalReports,
          pendingVerification,
          criticalReports,
          resolvedToday,
        },
        reportsByType: reportsByType.reduce((acc, item) => {
          acc[item.type] = item._count;
          return acc;
        }, {}),
        reportsByUrgency: reportsByUrgency.reduce((acc, item) => {
          acc[item.urgency] = item._count;
          return acc;
        }, {}),
        recentReports,
      },
    });
  } catch (error) {
    logger.error('Failed to get dashboard stats', { error: error.message });
    res.status(500).json({ success: false, error: error.message });
  }
}

/**
 * Get all users
 */
export async function getUsers(req, res) {
  try {
    const { role, isActive } = req.query;

    const where = {};
    if (role) where.role = role;
    if (isActive !== undefined) where.isActive = isActive === 'true';

    const users = await prisma.user.findMany({
      where,
      select: {
        id: true,
        phoneNumber: true,
        name: true,
        role: true,
        organization: true,
        isActive: true,
        trustLevel: true,
        createdAt: true,
        _count: {
          select: { reports: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    res.json({ success: true, data: users });
  } catch (error) {
    logger.error('Failed to get users', { error: error.message });
    res.status(500).json({ success: false, error: error.message });
  }
}

/**
 * Update user role/trust level
 */
export async function updateUser(req, res) {
  try {
    const { id } = req.params;
    const { role, trustLevel, isActive, organization } = req.body;
    const adminId = req.user.id;

    const user = await prisma.user.update({
      where: { id },
      data: {
        role,
        trustLevel,
        isActive,
        organization,
      },
    });

    // Audit log
    await prisma.auditLog.create({
      data: {
        userId: adminId,
        action: 'UPDATE',
        entityType: 'User',
        entityId: id,
        changes: { role, trustLevel, isActive, organization },
      },
    });

    logger.info('User updated', { userId: id, adminId });

    res.json({ success: true, data: user });
  } catch (error) {
    logger.error('Failed to update user', { error: error.message });
    res.status(500).json({ success: false, error: error.message });
  }
}

/**
 * Export reports (CSV)
 */
export async function exportReports(req, res) {
  try {
    const { type, status, startDate, endDate } = req.query;
    const userId = req.user.id;

    const where = {};
    if (type) where.type = type;
    if (status) where.status = status;
    if (startDate || endDate) {
      where.createdAt = {};
      if (startDate) where.createdAt.gte = new Date(startDate);
      if (endDate) where.createdAt.lte = new Date(endDate);
    }

    const reports = await prisma.report.findMany({
      where,
      include: {
        reporter: true,
        persons: true,
        needs: true,
      },
      orderBy: { createdAt: 'desc' },
    });

    // Create audit log for export
    await prisma.auditLog.create({
      data: {
        userId,
        action: 'EXPORT',
        entityType: 'Report',
        entityId: 'bulk',
        metadata: { count: reports.length, filters: { type, status, startDate, endDate } },
      },
    });

    logger.info('Reports exported', { count: reports.length, userId });

    // Return JSON (frontend can convert to CSV)
    res.json({ success: true, data: reports });
  } catch (error) {
    logger.error('Failed to export reports', { error: error.message });
    res.status(500).json({ success: false, error: error.message });
  }
}

/**
 * Health check endpoint
 */
export async function healthCheck(req, res) {
  try {
    const [ollamaHealth, whatsappHealth, telegramHealth, dbHealth] = await Promise.all([
      ollamaService.healthCheck().catch(() => ({ status: 'error' })),
      whatsappService.healthCheck().catch(() => ({ status: 'error' })),
      telegramService.healthCheck().catch(() => ({ status: 'error' })),
      prisma.$queryRaw`SELECT 1`.then(() => ({ status: 'healthy' })).catch(() => ({ status: 'error' })),
    ]);

    const overall = [ollamaHealth, whatsappHealth, telegramHealth, dbHealth].every(
      (h) => h.status === 'healthy'
    )
      ? 'healthy'
      : 'degraded';

    res.json({
      success: true,
      status: overall,
      services: {
        ollama: ollamaHealth,
        whatsapp: whatsappHealth,
        telegram: telegramHealth,
        database: dbHealth,
      },
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('Health check failed', { error: error.message });
    res.status(500).json({ success: false, error: error.message });
  }
}
