import express from 'express';
import * as webhookController from '../controllers/webhook.controller.js';
import * as apiController from '../controllers/api.controller.js';
import * as authController from '../controllers/auth.controller.js';
import * as mediaController from '../controllers/media.controller.js';
import { authenticate, authorize } from '../middleware/auth.middleware.js';

const router = express.Router();

// ============================================
// WEBHOOK ROUTES (WhatsApp)
// ============================================
router.get('/webhook', webhookController.verifyWebhook);
router.post('/webhook', webhookController.handleWebhook);

// ============================================
// AUTH ROUTES
// ============================================
router.post('/auth/login', authController.login);
router.post('/auth/setup-admin', authController.setupAdmin); // One-time setup
router.get('/auth/me', authenticate, authController.getCurrentUser);

// ============================================
// HEALTH CHECK (Public)
// ============================================
router.get('/health', apiController.healthCheck);

// ============================================
// API ROUTES (Authenticated)
// ============================================

// Reports
router.post('/api/reports', apiController.createReport); // Public endpoint for web forms
router.get('/api/reports', authenticate, apiController.getReports);
router.get('/api/reports/:id', authenticate, apiController.getReportById);
router.patch(
  '/api/reports/:id/status',
  authenticate,
  authorize('ADMIN', 'COORDINATOR', 'VOLUNTEER'),
  apiController.updateReportStatus
);

// Dashboard stats
router.get('/api/dashboard/stats', authenticate, apiController.getDashboardStats);

// Users management
router.get('/api/users', authenticate, authorize('ADMIN'), apiController.getUsers);
router.get('/api/users/:id', authenticate, authorize('ADMIN'), apiController.getUserById);
router.post('/api/users', authenticate, authorize('ADMIN'), apiController.createUser);
router.patch('/api/users/:id', authenticate, authorize('ADMIN'), apiController.updateUser);
router.delete('/api/users/:id', authenticate, authorize('ADMIN'), apiController.deleteUser);

// Export
router.get(
  '/api/reports/export',
  authenticate,
  authorize('ADMIN', 'PMI_BNPB'),
  apiController.exportReports
);

// Media routes
router.get('/api/media/:id', authenticate, mediaController.getMediaById);
router.get('/api/reports/:reportId/media', authenticate, mediaController.getReportMedia);
router.delete(
  '/api/media/:id',
  authenticate,
  authorize('ADMIN'),
  mediaController.deleteMedia
);
router.get(
  '/api/media/stats/storage',
  authenticate,
  authorize('ADMIN'),
  mediaController.getStorageStats
);

export default router;
