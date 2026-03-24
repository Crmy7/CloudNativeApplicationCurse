/* eslint-disable no-unused-vars */

const express = require('express');
const cors = require('cors');
const os = require('os');
const pino = require('pino');
require('dotenv').config();

const userRoutes = require('./routes/userRoutes');
const subscriptionRoutes = require('./routes/subscriptionRoutes');
const classRoutes = require('./routes/classRoutes');
const bookingRoutes = require('./routes/bookingRoutes');
const dashboardRoutes = require('./routes/dashboardRoutes');
const authRoutes = require('./routes/authRoutes');

const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  transport: process.env.NODE_ENV !== 'production' ? { target: 'pino-pretty' } : undefined
});

const app = express();

// Security: prevent Express from exposing its framework header
app.disable('x-powered-by');

const PORT = process.env.PORT || 3000;
const HOSTNAME = process.env.HOSTNAME || os.hostname();

// Structured logging middleware
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    logger.info({
      method: req.method,
      url: req.originalUrl,
      statusCode: res.statusCode,
      duration: Date.now() - start,
      hostname: HOSTNAME
    });
  });
  next();
});

// Middleware
app.use(cors({
  origin: process.env.FRONTEND_URL || 'http://localhost:8080',
  credentials: true
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Routes
app.use('/api/users', userRoutes);
app.use('/api/subscriptions', subscriptionRoutes);
app.use('/api/classes', classRoutes);
app.use('/api/bookings', bookingRoutes);
app.use('/api/dashboard', dashboardRoutes);
app.use('/api/auth', authRoutes);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'OK', hostname: HOSTNAME, timestamp: new Date().toISOString() });
});

// Whoami - returns hostname for load balancing verification
app.get('/whoami', (req, res) => {
  res.json({ hostname: HOSTNAME, platform: os.platform(), uptime: process.uptime() });
});

// Error handling middleware
app.use((err, req, res, next) => {
  logger.error({ err, hostname: HOSTNAME }, 'Unhandled error');
  res.status(500).json({
    error: 'Something went wrong!',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Internal server error'
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

app.listen(PORT, () => {
  logger.info({ port: PORT, hostname: HOSTNAME, env: process.env.NODE_ENV || 'development' }, 'Server started');
});
