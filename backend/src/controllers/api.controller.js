import prisma from '../config/database.js';
import logger from '../utils/logger.js';
import whatsappService from '../services/whatsapp.service.js';
import telegramService from '../services/telegram.service.js';
import ollamaService from '../services/ollama.service.js';

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
 * Create new report from web form (public endpoint)
 */
export async function createReport(req, res) {
  try {
    const { type, urgency, reportSource, reporterPhone, location, latitude, longitude, shelter, missingPerson, needs } = req.body;

    // Validate required fields
    if (!type || !reporterPhone || !location) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: type, reporterPhone, location'
      });
    }

    // Find or create user (reporter)
    let user = await prisma.user.findUnique({
      where: { phoneNumber: reporterPhone },
    });

    if (!user) {
      // Create new user for web reporter
      user = await prisma.user.create({
        data: {
          phoneNumber: reporterPhone,
          name: shelter?.picName || missingPerson?.familyName || 'Web Reporter',
          role: 'VOLUNTEER',
          trustLevel: 0,
        },
      });
      logger.info('Created new user from web form', { phoneNumber: reporterPhone });
    }

    // Generate report number
    const reportNumber = await generateReportNumber(type, user.role === 'ADMIN');

    // Build summary based on report type
    let summary = '';
    let extractedData = {};

    if (type === 'PENGUNGSIAN' && shelter) {
      const totalPeople = (shelter.maleCount || 0) + (shelter.femaleCount || 0) + (shelter.childCount || 0);
      summary = `Posko Pengungsian ${shelter.type} - ${totalPeople} orang mengungsi`;
      extractedData = { shelter };
    } else if (type === 'KORBAN' && missingPerson) {
      summary = `Pencarian orang hilang: ${missingPerson.personName}, ${missingPerson.age} tahun`;
      extractedData = { missingPerson };
    } else if (type === 'KEBUTUHAN' && needs) {
      summary = `Request bantuan ${needs.category || 'umum'}`;
      extractedData = { needs };
    }

    // Create report
    const report = await prisma.report.create({
      data: {
        reportNumber,
        type,
        status: 'PENDING_VERIFICATION',
        urgency: urgency || 'MEDIUM',
        reporterId: user.id,
        reporterPhone: user.phoneNumber,
        reportSource: reportSource || 'web',
        location,
        latitude: latitude ? parseFloat(latitude) : null,
        longitude: longitude ? parseFloat(longitude) : null,
        summary,
        rawMessage: JSON.stringify(req.body),
        extractedData,
      },
      include: {
        reporter: true,
      },
    });

    // Create person record if missing person report
    if (type === 'KORBAN' && missingPerson) {
      await prisma.reportPerson.create({
        data: {
          reportId: report.id,
          name: missingPerson.personName,
          nik: missingPerson.idNumber || null,
          gender: missingPerson.gender || null,
          age: missingPerson.age ? parseInt(missingPerson.age) : null,
          status: 'HILANG',
          condition: missingPerson.physicalDescription || null,
          lastSeenLocation: missingPerson.lastSeenLocation || null,
          familyContact: missingPerson.familyName || null,
          familyPhone: missingPerson.familyPhone || null,
          photoUrl: missingPerson.photoBase64 ? 'base64-stored' : null,
          notes: `Provinsi: ${missingPerson.province || '-'}, Kota: ${missingPerson.city || '-'}, Kecamatan: ${missingPerson.district || '-'}`,
        },
      });

      // TODO: Handle photo upload if missingPerson.photoBase64 exists
      if (missingPerson.photoBase64) {
        logger.info('Photo upload for missing person', { reportId: report.id });
        // Future: Save base64 photo to media storage
      }
    }

    // Create need records if kebutuhan report
    if (type === 'KEBUTUHAN' && needs) {
      await prisma.reportNeed.create({
        data: {
          reportId: report.id,
          category: needs.category || 'LOGISTIK_LAIN',
          description: needs.description || summary,
          quantity: needs.quantity || null,
          peopleAffected: needs.peopleAffected ? parseInt(needs.peopleAffected) : null,
          status: 'BELUM_TERPENUHI',
        },
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
          source: reportSource || 'web',
          formType: type,
        },
      },
    });

    logger.info('Report created from web form', {
      reportId: report.id,
      reportNumber: report.reportNumber,
      type,
      userId: user.id
    });

    res.status(201).json({
      success: true,
      data: report,
      message: 'Laporan berhasil dikirim. Terima kasih!'
    });
  } catch (error) {
    logger.error('Failed to create report', { error: error.message, stack: error.stack });
    res.status(500).json({ success: false, error: 'Gagal membuat laporan. Silakan coba lagi.' });
  }
}

/**
 * Generate report number helper
 */
async function generateReportNumber(type, isVerified) {
  const prefix = isVerified ? 'VR' : 'PB';
  const typePrefix = type === 'KORBAN' ? 'K' : type === 'KEBUTUHAN' ? 'N' : 'P';

  // Get count of reports today
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const count = await prisma.report.count({
    where: {
      type,
      createdAt: { gte: today },
    },
  });

  const sequence = (count + 1).toString().padStart(3, '0');
  const dateStr = today.toISOString().slice(5, 10).replace('-', '');

  return `${prefix}-${typePrefix}${dateStr}-${sequence}`;
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
    const { role, isActive, search, page = 1, limit = 20 } = req.query;

    const where = {};
    if (role) where.role = role;
    if (isActive !== undefined) where.isActive = isActive === 'true';

    if (search) {
      where.OR = [
        { name: { contains: search, mode: 'insensitive' } },
        { phoneNumber: { contains: search } },
        { organization: { contains: search, mode: 'insensitive' } },
      ];
    }

    const [users, total] = await Promise.all([
      prisma.user.findMany({
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
        skip: (page - 1) * limit,
        take: parseInt(limit),
      }),
      prisma.user.count({ where }),
    ]);

    res.json({
      success: true,
      data: users,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        totalPages: Math.ceil(total / limit),
      },
    });
  } catch (error) {
    logger.error('Failed to get users', { error: error.message });
    res.status(500).json({ success: false, error: error.message });
  }
}

/**
 * Get single user by ID
 */
export async function getUserById(req, res) {
  try {
    const { id } = req.params;

    const user = await prisma.user.findUnique({
      where: { id },
      select: {
        id: true,
        phoneNumber: true,
        name: true,
        role: true,
        organization: true,
        isActive: true,
        trustLevel: true,
        createdAt: true,
        updatedAt: true,
        _count: {
          select: {
            reports: true,
            assignedCases: true,
          },
        },
      },
    });

    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }

    res.json({ success: true, data: user });
  } catch (error) {
    logger.error('Failed to get user', { error: error.message });
    res.status(500).json({ success: false, error: error.message });
  }
}

/**
 * Create new user
 */
export async function createUser(req, res) {
  try {
    const { phoneNumber, name, role, organization, isActive = true, trustLevel = 0 } = req.body;
    const adminId = req.user.id;

    if (!phoneNumber || !name || !role) {
      return res.status(400).json({
        success: false,
        error: 'Phone number, name, and role are required',
      });
    }

    // Check if user already exists
    const existing = await prisma.user.findUnique({
      where: { phoneNumber },
    });

    if (existing) {
      return res.status(409).json({
        success: false,
        error: 'User with this phone number already exists',
      });
    }

    const user = await prisma.user.create({
      data: {
        phoneNumber,
        name,
        role,
        organization,
        isActive,
        trustLevel,
      },
    });

    // Audit log
    await prisma.auditLog.create({
      data: {
        userId: adminId,
        action: 'CREATE',
        entityType: 'User',
        entityId: user.id,
        changes: { phoneNumber, name, role, organization },
      },
    });

    logger.info('User created', { userId: user.id, adminId });

    res.status(201).json({ success: true, data: user });
  } catch (error) {
    logger.error('Failed to create user', { error: error.message });
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
 * Delete user
 */
export async function deleteUser(req, res) {
  try {
    const { id } = req.params;
    const adminId = req.user.id;

    // Check if user exists
    const user = await prisma.user.findUnique({
      where: { id },
    });

    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }

    // Prevent deleting yourself
    if (id === adminId) {
      return res.status(400).json({
        success: false,
        error: 'Cannot delete your own account',
      });
    }

    // Soft delete by deactivating
    await prisma.user.update({
      where: { id },
      data: { isActive: false },
    });

    // Audit log
    await prisma.auditLog.create({
      data: {
        userId: adminId,
        action: 'DELETE',
        entityType: 'User',
        entityId: id,
        changes: { deleted: true },
      },
    });

    logger.info('User deleted (deactivated)', { userId: id, adminId });

    res.json({ success: true, message: 'User deactivated successfully' });
  } catch (error) {
    logger.error('Failed to delete user', { error: error.message });
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
