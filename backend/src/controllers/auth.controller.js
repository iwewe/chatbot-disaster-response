import bcrypt from 'bcrypt';
import prisma from '../config/database.js';
import { generateToken } from '../middleware/auth.middleware.js';
import logger from '../utils/logger.js';

/**
 * Login with phone number and password (for dashboard access)
 * In emergency MVP: simple phone number auth
 */
export async function login(req, res) {
  try {
    // Accept either phoneNumber or username (username is treated as phoneNumber)
    const { phoneNumber, username, password } = req.body;
    const loginIdentifier = phoneNumber || username;

    if (!loginIdentifier) {
      return res.status(400).json({ success: false, error: 'Phone number or username required' });
    }

    const user = await prisma.user.findUnique({
      where: { phoneNumber: loginIdentifier },
    });

    if (!user) {
      return res.status(401).json({ success: false, error: 'Invalid credentials' });
    }

    if (!user.isActive) {
      return res.status(403).json({ success: false, error: 'User is inactive' });
    }

    // For MVP: simple password check (in production, use bcrypt hash)
    // For emergency: if no password set, allow login with phone number only for ADMIN role
    // This is ONLY for emergency MVP - should be replaced with proper auth
    if (password) {
      const isValid = password === process.env.ADMIN_PASSWORD || false;
      if (!isValid) {
        return res.status(401).json({ success: false, error: 'Invalid credentials' });
      }
    } else if (user.role !== 'ADMIN') {
      return res.status(401).json({ success: false, error: 'Password required' });
    }

    const token = generateToken(user);

    logger.info('User logged in', { userId: user.id, role: user.role });

    res.json({
      success: true,
      data: {
        token,
        user: {
          id: user.id,
          phoneNumber: user.phoneNumber,
          name: user.name,
          role: user.role,
          organization: user.organization,
        },
      },
    });
  } catch (error) {
    logger.error('Login failed', { error: error.message });
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
}

/**
 * Get current user info
 */
export async function getCurrentUser(req, res) {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      select: {
        id: true,
        phoneNumber: true,
        name: true,
        role: true,
        organization: true,
        trustLevel: true,
        createdAt: true,
      },
    });

    res.json({ success: true, data: user });
  } catch (error) {
    logger.error('Failed to get current user', { error: error.message });
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
}

/**
 * Emergency admin setup (one-time use)
 * Creates initial admin user if none exists
 */
export async function setupAdmin(req, res) {
  try {
    // Check if admin already exists
    const existingAdmin = await prisma.user.findFirst({
      where: { role: 'ADMIN' },
    });

    if (existingAdmin) {
      return res.status(400).json({
        success: false,
        error: 'Admin already exists',
      });
    }

    const { phoneNumber, name, password } = req.body;

    if (!phoneNumber || !name) {
      return res.status(400).json({
        success: false,
        error: 'Phone number and name required',
      });
    }

    // Create admin user
    const admin = await prisma.user.create({
      data: {
        phoneNumber,
        name,
        role: 'ADMIN',
        trustLevel: 5,
        isActive: true,
      },
    });

    // Store password in env (for MVP only - replace with proper auth later)
    // In production, hash with bcrypt and store in database
    if (password) {
      logger.warn('IMPORTANT: Set ADMIN_PASSWORD in .env to:', { password });
    }

    const token = generateToken(admin);

    logger.info('Admin user created', { userId: admin.id });

    res.json({
      success: true,
      message: 'Admin created successfully',
      data: {
        token,
        user: {
          id: admin.id,
          phoneNumber: admin.phoneNumber,
          name: admin.name,
          role: admin.role,
        },
      },
    });
  } catch (error) {
    logger.error('Failed to setup admin', { error: error.message });
    res.status(500).json({ success: false, error: error.message });
  }
}
