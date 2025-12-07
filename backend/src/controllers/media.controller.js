import prisma from '../config/database.js';
import mediaService from '../services/media.service.js';
import logger from '../utils/logger.js';
import fs from 'fs';

/**
 * Get media file by ID
 */
export async function getMediaById(req, res) {
  try {
    const { id } = req.params;

    const media = await prisma.reportMedia.findUnique({
      where: { id },
      include: {
        report: {
          select: {
            id: true,
            reportNumber: true,
            type: true,
          },
        },
      },
    });

    if (!media) {
      return res.status(404).json({ success: false, error: 'Media not found' });
    }

    // Get full file path
    const fullPath = mediaService.getFullPath(media.filePath);

    // Check if file exists
    if (!fs.existsSync(fullPath)) {
      logger.error('Media file not found on disk', { mediaId: id, path: fullPath });
      return res.status(404).json({ success: false, error: 'Media file not found on disk' });
    }

    // Send file
    res.sendFile(fullPath, (err) => {
      if (err) {
        logger.error('Failed to send media file', { error: err.message });
        res.status(500).json({ success: false, error: 'Failed to send file' });
      }
    });
  } catch (error) {
    logger.error('Failed to get media', { error: error.message });
    res.status(500).json({ success: false, error: error.message });
  }
}

/**
 * Get all media for a report
 */
export async function getReportMedia(req, res) {
  try {
    const { reportId } = req.params;

    const media = await prisma.reportMedia.findMany({
      where: { reportId },
      orderBy: { uploadedAt: 'desc' },
    });

    res.json({
      success: true,
      data: media,
    });
  } catch (error) {
    logger.error('Failed to get report media', { error: error.message });
    res.status(500).json({ success: false, error: error.message });
  }
}

/**
 * Delete media (admin only)
 */
export async function deleteMedia(req, res) {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    const media = await prisma.reportMedia.findUnique({
      where: { id },
    });

    if (!media) {
      return res.status(404).json({ success: false, error: 'Media not found' });
    }

    // Delete file from disk
    await mediaService.deleteMedia(media.filePath);

    // Delete from database
    await prisma.reportMedia.delete({
      where: { id },
    });

    // Create audit log
    await prisma.auditLog.create({
      data: {
        userId,
        action: 'DELETE',
        entityType: 'ReportMedia',
        entityId: id,
        reportId: media.reportId,
        metadata: {
          fileName: media.fileName,
          mediaType: media.mediaType,
        },
      },
    });

    logger.info('Media deleted', { mediaId: id, userId });

    res.json({ success: true, message: 'Media deleted successfully' });
  } catch (error) {
    logger.error('Failed to delete media', { error: error.message });
    res.status(500).json({ success: false, error: error.message });
  }
}

/**
 * Get storage statistics
 */
export async function getStorageStats(req, res) {
  try {
    const stats = await mediaService.getStorageStats();

    const mediaCount = await prisma.reportMedia.groupBy({
      by: ['mediaType'],
      _count: true,
    });

    res.json({
      success: true,
      data: {
        storage: stats,
        mediaCount: mediaCount.reduce((acc, item) => {
          acc[item.mediaType] = item._count;
          return acc;
        }, {}),
      },
    });
  } catch (error) {
    logger.error('Failed to get storage stats', { error: error.message });
    res.status(500).json({ success: false, error: error.message });
  }
}
