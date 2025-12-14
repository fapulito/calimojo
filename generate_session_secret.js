#!/usr/bin/env node

/**
 * Session Secret Generator
 * Generates cryptographically secure session secrets for Mojopoker
 * Usage: node generate_session_secret.js [length]
 */

const crypto = require('crypto');

// Get desired length from command line argument, default to 32 bytes (64 hex chars)
const bytes = parseInt(process.argv[2]) || 32;

// Generate secure random bytes
const secret = crypto.randomBytes(bytes).toString('hex');

console.log('🔐 New Session Secret Generated:');
console.log(secret);
console.log(`\n📏 Length: ${secret.length} characters (${bytes} bytes)`);
console.log('🔒 Security: Cryptographically secure random bytes');
console.log('📝 Format: Hexadecimal encoding');
console.log('\n📋 Update Instructions:');
console.log('1. Copy the secret above');
console.log('2. Update vercel/.env file: SESSION_SECRET=your_new_secret');
console.log('3. Update Perl files if needed (FB/Db.pm and FB.pm)');
console.log('4. Restart all server instances');
console.log('\n⚠️  IMPORTANT: Keep this secret secure!');
console.log('   - Never commit to version control');
console.log('   - Restrict file permissions');
console.log('   - Rotate regularly (every 3-6 months)');
console.log('   - Invalidate all sessions after rotation');