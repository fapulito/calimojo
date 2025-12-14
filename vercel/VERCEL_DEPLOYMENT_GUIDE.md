# Vercel Deployment Guide for Mojo Poker

## Why It Works Locally But Not on Vercel

This guide explains the key differences between local development and Vercel production that cause deployment issues.

### 1. Environment Variables

**Local Development:**
- Uses `.env` files loaded by `dotenv.config()`
- Variables are automatically available in `process.env`
- Missing variables fall back to defaults or cause errors during development

**Vercel Production:**
- Requires environment variables to be explicitly set in the Vercel dashboard
- No `.env` files are used in production
- Missing variables cause runtime errors, not build errors

### 2. Fixed Issues

#### Issue 1: Duplicate Environment Variable References
**Problem:** In `api/index.js`, there were duplicate references:
```javascript
clientID: process.env.FACEBOOK_APP_ID || process.env.FACEBOOK_APP_ID,
clientSecret: process.env.FACEBOOK_APP_SECRET || process.env.FACEBOOK_APP_SECRET,
```

**Solution:** Fixed to use single references:
```javascript
clientID: process.env.FACEBOOK_APP_ID,
clientSecret: process.env.FACEBOOK_APP_SECRET,
```

#### Issue 2: Missing Environment Variable Validation
**Problem:** The code didn't validate that required environment variables were set.

**Solution:** Added validation in `api/auth/facebook.js`:
```javascript
const facebookAppId = process.env.FACEBOOK_APP_ID
const facebookAppSecret = process.env.FACEBOOK_APP_SECRET

if (!facebookAppId || !facebookAppSecret) {
  console.error('Missing Facebook environment variables')
  return res.status(500).json({
    error: 'Server configuration error',
    details: 'Facebook app credentials not configured'
  })
}
```

### 3. Vercel Configuration Instructions

#### Step 1: Set Environment Variables in Vercel Dashboard
1. Go to your Vercel project dashboard
2. Navigate to **Settings** > **Environment Variables**
3. Add the following variables:

| Variable Name | Required | Description |
|---------------|----------|-------------|
| `FACEBOOK_APP_ID` | ✅ Yes | Your Facebook App ID |
| `FACEBOOK_APP_SECRET` | ✅ Yes | Your Facebook App Secret |
| `FACEBOOK_CALLBACK_URL` | ❌ No | Facebook callback URL (defaults to `/auth/facebook/callback`) |
| `SESSION_SECRET` | ❌ No | Session secret (defaults to `'default_session_secret'`) |
| `SESSION_MAX_AGE` | ❌ No | Session max age in ms (defaults to `86400000` - 24 hours) |
| `NODE_ENV` | ❌ No | Automatically set to `production` by Vercel |

#### Step 2: Facebook App Configuration
1. Go to [Facebook Developer Portal](https://developers.facebook.com/)
2. Configure your Facebook App:
   - Set **Valid OAuth Redirect URIs** to: `https://your-app-name.vercel.app/auth/facebook/callback`
   - Ensure your app is in **Live** mode for production
   - Add your Vercel domain to **App Domains**

#### Step 3: CORS Configuration
Update the CORS origin in both `api/index.js` and `lib/server.js`:

```javascript
cors({
  origin: process.env.NODE_ENV === 'production' ? 'https://your-app-name.vercel.app' : 'http://localhost:3000',
  credentials: true
})
```

### 4. Debugging Tips

**If you still have issues:**

1. **Check Vercel Build Logs:**
   - Go to **Deployments** > Select your deployment > **Build Logs**
   - Look for any environment variable warnings

2. **Add Debug Logging:**
   Add this to your server startup code:
   ```javascript
   console.log('Environment Variables:');
   console.log('FACEBOOK_APP_ID:', process.env.FACEBOOK_APP_ID ? 'Set' : 'Not Set');
   console.log('FACEBOOK_APP_SECRET:', process.env.FACEBOOK_APP_SECRET ? 'Set' : 'Not Set');
   console.log('NODE_ENV:', process.env.NODE_ENV);
   ```

3. **Test Locally with Production Settings:**
   ```bash
   NODE_ENV=production FACEBOOK_APP_ID=your_id FACEBOOK_APP_SECRET=your_secret npm start
   ```

### 5. Common Pitfalls

1. **Variable Name Mismatch:** Ensure the variable names in Vercel exactly match what your code expects (`FACEBOOK_APP_ID`, not `FACEBOOK_ID` or similar)

2. **Variable Scope:** Make sure variables are set for the correct environment (Production vs Preview)

3. **Restart Required:** After changing environment variables, you may need to redeploy for changes to take effect

4. **Case Sensitivity:** Environment variable names are case-sensitive

## Support

If you're still experiencing issues, the problem is likely one of:
1. Environment variables not properly set in Vercel dashboard
2. Facebook App configuration mismatch
3. CORS/origin configuration issues

The code now properly validates environment variables and provides clear error messages to help diagnose these issues.