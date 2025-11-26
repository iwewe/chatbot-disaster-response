import express from 'express';
import * as webhookController from '../controllers/webhook.controller.js';
import * as apiController from '../controllers/api.controller.js';
import * as authController from '../controllers/auth.controller.js';
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
router.patch('/api/users/:id', authenticate, authorize('ADMIN'), apiController.updateUser);

// Export
router.get(
  '/api/reports/export',
  authenticate,
  authorize('ADMIN', 'PMI_BNPB'),
  apiController.exportReports
);

export default router;
