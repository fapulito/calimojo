# Mojo Poker Code Review & Deployment Guide

## Table of Contents

1. [Current Codebase Analysis](#current-codebase-analysis)
2. [AlmaLinux Deployment](#almalinux-deployment)
3. [Vercel Deployment](#vercel-deployment)
4. [Database Migration](#database-migration)
5. [Facebook Authentication](#facebook-authentication)
6. [Security Considerations](#security-considerations)
7. [Performance Optimization](#performance-optimization)
8. [Future Enhancements](#future-enhancements)

## Current Codebase Analysis

### Architecture Overview

- **Backend**: Perl (Mojolicious) with WebSocket support
- **Frontend**: jQuery-based UI with Facebook SDK integration
- **Database**: SQLite (with new PostgreSQL support)
- **Authentication**: Facebook OAuth 2.0
- **Deployment**: Systemd service

### Strengths

1. **Comprehensive Game Engine**: Supports 30+ poker variants
2. **Real-time Communication**: WebSocket-based updates
3. **Modular Design**: Well-organized code structure
4. **Cross-platform Potential**: Now supports both SQLite and PostgreSQL

### Areas for Improvement

1. **Modernization**: Legacy jQuery code could benefit from React/Vue rewrite
2. **Security**: Hardcoded credentials (now fixed with environment variables)
3. **Error Handling**: Could be more robust in some areas
4. **Documentation**: Limited inline documentation

## AlmaLinux Deployment

### Installation Process

1. **Run the installation script**:

   ```bash
   sudo ./install_almalinux
   ```

2. **Configure environment variables**:

   ```bash
   sudo nano /opt/mojopoker/.env
   ```

3. **Start the service**:

   ```bash
   sudo systemctl start mojopoker.service
   ```

### Key Features

- **Automatic Dependency Installation**: Handles all Perl modules and system packages
- **Database Flexibility**: Supports both SQLite and PostgreSQL
- **Systemd Integration**: Proper service management
- **Environment Variables**: Secure configuration management

### PostgreSQL Setup

The installation script includes optional PostgreSQL setup:

- Creates database and user
- Imports schema
- Configures connection settings

## Vercel Deployment

### Architecture

```text
vercel/
├── api/              # API endpoints
│   ├── auth/         # Authentication APIs
│   └── poker/        # Game APIs
├── pages/            # Next.js pages
├── lib/              # Utility functions
├── public/           # Static assets
└── vercel.json       # Vercel configuration
```

### Deployment Steps

1. **Set up environment variables in Vercel dashboard**:
   - `FACEBOOK_APP_ID`
   - `FACEBOOK_APP_SECRET`
   - `DATABASE_URL` (for PostgreSQL)
   - `NEXT_PUBLIC_FACEBOOK_APP_ID`

2. **Deploy the Next.js application**:

   ```bash
   cd vercel
   npm install
   npm run build
   vercel deploy
   ```

### WebSocket Proxy

The Vercel deployment includes a WebSocket proxy to handle real-time communication between the frontend and backend.

## Database Migration

### SQLite to PostgreSQL

The migration script (`db/migrate.pl`) handles:

- User data migration
- Schema conversion
- Data type mapping
- Error handling

### Usage

```bash
DATABASE_URL="postgresql://user:password@host:port/db" perl migrate.pl --verbose
```

### Schema Differences

| Feature | SQLite | PostgreSQL |
|---------|--------|------------|
| Data Types | Limited | Rich (JSONB, etc.) |
| Concurrency | Basic | Advanced |
| Scalability | Limited | High |
| Functions | Basic | PL/pgSQL |

## Facebook Authentication

### Implementation

1. **Frontend**: Facebook JavaScript SDK v18.0
2. **Backend**: Signed request validation
3. **Environment Variables**: Secure credential management

### Flow

1. User clicks Facebook login button
2. Facebook SDK handles OAuth flow
3. Signed request sent to backend
4. Backend validates and creates session
5. User data fetched from Facebook API

### Security Enhancements

- **Environment Variables**: No hardcoded credentials
- **Signed Request Validation**: Proper signature verification
- **Token Management**: Secure session handling

## Security Considerations

### Implemented Security Measures

1. **Environment Variables**: For all sensitive credentials
2. **HTTPS**: Required for Facebook authentication
3. **CORS**: Proper headers in Vercel configuration
4. **Input Validation**: In Perl backend

### Recommended Additional Security

1. **Rate Limiting**: For API endpoints
2. **CSRF Protection**: For form submissions
3. **JWT Tokens**: For session management
4. **Database Encryption**: For sensitive user data

## Performance Optimization

### Current Optimizations

1. **WebSocket Communication**: Real-time updates
2. **Client-side Rendering**: Reduced server load
3. **Database Indexing**: Faster queries

### Recommended Optimizations

1. **Caching**: For game state and user data
2. **CDN**: For static assets
3. **Database Connection Pooling**: For PostgreSQL
4. **Code Splitting**: For frontend bundle

## Future Enhancements

### Short-term

1. **Tournament Support**: Add tournament functionality
2. **Mobile Optimization**: Better mobile experience
3. **UI Modernization**: React/Vue rewrite
4. **Analytics**: Game statistics and insights

### Long-term

1. **Multi-table Tournaments**: Large-scale events
2. **AI Opponents**: For solo play
3. **Virtual Currency**: In-app purchases
4. **Social Features**: Friends list, chat enhancements

## Deployment Checklist

### AlmaLinux

- [ ] Run installation script
- [ ] Configure environment variables
- [ ] Set up database (SQLite or PostgreSQL)
- [ ] Start systemd service
- [ ] Test WebSocket connection
- [ ] Verify Facebook authentication

### Vercel

- [ ] Set up Vercel project
- [ ] Configure environment variables
- [ ] Deploy Next.js application
- [ ] Test API endpoints
- [ ] Verify WebSocket proxy
- [ ] Test Facebook login flow

## Troubleshooting

### Common Issues

1. **Facebook Login Not Working**: Check app domain settings
2. **WebSocket Connection Failed**: Verify CORS headers
3. **Database Connection Errors**: Check environment variables
4. **Perl Module Missing**: Run `cpanm Missing::Module`

### Debugging Tips

- Check logs: `journalctl -u mojopoker.service`
- Test WebSocket: `wscat -c ws://localhost:3000/websocket`
- Verify environment: `printenv | grep FACEBOOK`

## Conclusion

This implementation provides a robust foundation for Mojo Poker deployment on both AlmaLinux and Vercel platforms. The addition of PostgreSQL support enables scalability, while the environment variable management ensures security. The Vercel deployment brings modern frontend capabilities while maintaining the core gameplay functionality.

The codebase is now ready for production deployment with proper Facebook app configuration and database setup.
