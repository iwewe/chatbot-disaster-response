import axios from 'axios';
import fs from 'fs';
import path from 'path';
import config from '../config/env.js';
import logger from '../utils/logger.js';

class MediaService {
  constructor() {
    this.storageDir = process.env.MEDIA_STORAGE_PATH || '/app/media';
    this.maxImageSize = 16 * 1024 * 1024; // 16MB (WhatsApp limit)
    this.maxVideoSize = 64 * 1024 * 1024; // 64MB
    this.maxDocumentSize = 100 * 1024 * 1024; // 100MB

    // Create storage directory if not exists
    this.initializeStorage();
  }

  /**
   * Initialize storage directory
   */
  initializeStorage() {
    try {
      if (!fs.existsSync(this.storageDir)) {
        fs.mkdirSync(this.storageDir, { recursive: true });
        logger.info('Media storage directory created', { path: this.storageDir });
      }

      // Create subdirectories for each media type
      const subdirs = ['images', 'videos', 'audio', 'documents'];
      subdirs.forEach((subdir) => {
        const dirPath = path.join(this.storageDir, subdir);
        if (!fs.existsSync(dirPath)) {
          fs.mkdirSync(dirPath, { recursive: true });
        }
      });
    } catch (error) {
      logger.error('Failed to initialize media storage', { error: error.message });
    }
  }

  /**
   * Download media from WhatsApp
   */
  async downloadWhatsAppMedia(mediaId, mediaType) {
    try {
      logger.info('Downloading WhatsApp media', { mediaId, mediaType });

      // Step 1: Get media URL from WhatsApp
      const mediaUrlResponse = await axios.get(
        `https://graph.facebook.com/v18.0/${mediaId}`,
        {
          headers: {
            Authorization: `Bearer ${config.whatsapp.accessToken}`,
          },
        }
      );

      const mediaUrl = mediaUrlResponse.data.url;
      const mimeType = mediaUrlResponse.data.mime_type;
      const fileSize = mediaUrlResponse.data.file_size;

      logger.debug('Media URL retrieved', { mediaUrl, mimeType, fileSize });

      // Step 2: Download media file
      const mediaResponse = await axios.get(mediaUrl, {
        headers: {
          Authorization: `Bearer ${config.whatsapp.accessToken}`,
        },
        responseType: 'arraybuffer',
        maxContentLength: this.maxDocumentSize,
        timeout: 60000, // 60s timeout for large files
      });

      const buffer = Buffer.from(mediaResponse.data);

      // Step 3: Determine file extension
      const extension = this.getFileExtension(mimeType);

      // Step 4: Generate unique filename
      const timestamp = Date.now();
      const randomString = Math.random().toString(36).substring(7);
      const fileName = `${timestamp}_${randomString}${extension}`;

      // Step 5: Determine storage subdirectory
      const subdir = this.getStorageSubdir(mediaType);

      // Step 6: Save file
      const filePath = path.join(this.storageDir, subdir, fileName);
      fs.writeFileSync(filePath, buffer);

      logger.info('Media downloaded successfully', {
        mediaId,
        fileName,
        fileSize: buffer.length,
      });

      return {
        success: true,
        fileName,
        filePath: path.join(subdir, fileName), // Relative path for DB
        fileSize: buffer.length,
        mimeType,
      };
    } catch (error) {
      logger.error('Failed to download WhatsApp media', {
        mediaId,
        error: error.message,
      });

      return {
        success: false,
        error: error.message,
      };
    }
  }

  /**
   * Get file extension from MIME type
   */
  getFileExtension(mimeType) {
    const mimeToExt = {
      // Images
      'image/jpeg': '.jpg',
      'image/png': '.png',
      'image/gif': '.gif',
      'image/webp': '.webp',

      // Videos
      'video/mp4': '.mp4',
      'video/3gpp': '.3gp',
      'video/quicktime': '.mov',

      // Audio
      'audio/ogg': '.ogg',
      'audio/mpeg': '.mp3',
      'audio/mp4': '.m4a',
      'audio/amr': '.amr',

      // Documents
      'application/pdf': '.pdf',
      'application/msword': '.doc',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document': '.docx',
      'application/vnd.ms-excel': '.xls',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': '.xlsx',
      'text/plain': '.txt',
    };

    return mimeToExt[mimeType] || '.bin';
  }

  /**
   * Get storage subdirectory based on media type
   */
  getStorageSubdir(mediaType) {
    const typeMap = {
      IMAGE: 'images',
      VIDEO: 'videos',
      AUDIO: 'audio',
      DOCUMENT: 'documents',
    };

    return typeMap[mediaType] || 'documents';
  }

  /**
   * Get full file path (for serving files)
   */
  getFullPath(relativePath) {
    return path.join(this.storageDir, relativePath);
  }

  /**
   * Delete media file
   */
  async deleteMedia(relativePath) {
    try {
      const fullPath = this.getFullPath(relativePath);

      if (fs.existsSync(fullPath)) {
        fs.unlinkSync(fullPath);
        logger.info('Media deleted', { path: relativePath });
        return { success: true };
      }

      logger.warn('Media file not found for deletion', { path: relativePath });
      return { success: false, error: 'File not found' };
    } catch (error) {
      logger.error('Failed to delete media', { path: relativePath, error: error.message });
      return { success: false, error: error.message };
    }
  }

  /**
   * Get media type from MIME type
   */
  getMediaTypeFromMime(mimeType) {
    if (mimeType.startsWith('image/')) return 'IMAGE';
    if (mimeType.startsWith('video/')) return 'VIDEO';
    if (mimeType.startsWith('audio/')) return 'AUDIO';
    return 'DOCUMENT';
  }

  /**
   * Validate media size
   */
  validateMediaSize(mediaType, fileSize) {
    const limits = {
      IMAGE: this.maxImageSize,
      VIDEO: this.maxVideoSize,
      AUDIO: this.maxImageSize,
      DOCUMENT: this.maxDocumentSize,
    };

    const limit = limits[mediaType] || this.maxDocumentSize;

    if (fileSize > limit) {
      return {
        valid: false,
        error: `File too large. Max size for ${mediaType}: ${this.formatBytes(limit)}`,
      };
    }

    return { valid: true };
  }

  /**
   * Format bytes to human-readable
   */
  formatBytes(bytes) {
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(2) + ' KB';
    return (bytes / (1024 * 1024)).toFixed(2) + ' MB';
  }

  /**
   * Get storage statistics
   */
  async getStorageStats() {
    try {
      const stats = {
        total: 0,
        byType: {
          images: 0,
          videos: 0,
          audio: 0,
          documents: 0,
        },
      };

      const subdirs = ['images', 'videos', 'audio', 'documents'];

      for (const subdir of subdirs) {
        const dirPath = path.join(this.storageDir, subdir);
        if (fs.existsSync(dirPath)) {
          const files = fs.readdirSync(dirPath);
          for (const file of files) {
            const filePath = path.join(dirPath, file);
            const fileStats = fs.statSync(filePath);
            stats.byType[subdir] += fileStats.size;
            stats.total += fileStats.size;
          }
        }
      }

      return {
        total: this.formatBytes(stats.total),
        totalBytes: stats.total,
        byType: {
          images: this.formatBytes(stats.byType.images),
          videos: this.formatBytes(stats.byType.videos),
          audio: this.formatBytes(stats.byType.audio),
          documents: this.formatBytes(stats.byType.documents),
        },
      };
    } catch (error) {
      logger.error('Failed to get storage stats', { error: error.message });
      return null;
    }
  }
}

export default new MediaService();
