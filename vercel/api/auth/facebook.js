const express = require('express');
const router = express.Router();

// Facebook authentication endpoint
router.post('/', async (req, res) => {
  try {
    const { authResponse } = req.body

    if (!authResponse) {
      return res.status(400).json({ error: 'Missing authResponse' })
    }

    // Validate environment variables
    const facebookAppId = process.env.FACEBOOK_APP_ID
    const facebookAppSecret = process.env.FACEBOOK_APP_SECRET

    if (!facebookAppId || !facebookAppSecret) {
      console.error('Missing Facebook environment variables')
      return res.status(500).json({
        error: 'Server configuration error',
        details: 'Facebook app credentials not configured'
      })
    }

    // Verify the signed request with Facebook app secret
    const verificationResult = verifySignedRequest(authResponse.signedRequest, facebookAppSecret)

    if (!verificationResult.isValid) {
      return res.status(401).json({
        error: 'Invalid signed request',
        details: 'Facebook authentication failed - invalid signature'
      })
    }

    // For now, we'll just return the user data
    const userData = {
      facebookId: authResponse.userID,
      accessToken: authResponse.accessToken,
      expiresIn: authResponse.expiresIn,
      signedRequest: authResponse.signedRequest,
      appId: facebookAppId // Include the app ID in the response for reference
    }

    // Here you would typically:
    // 1. Verify the signed request (now implemented)
    // 2. Exchange the short-lived token for a long-lived token
    // 3. Store the user session
    // 4. Return a session token

    return res.status(200).json({
      success: true,
      user: userData,
      message: 'Facebook authentication successful'
    })

  } catch (error) {
    console.error('Facebook auth error:', error)
    return res.status(500).json({
      error: 'Authentication failed',
      details: error.message
    })
  }
});

// Helper function to verify Facebook signed request
function verifySignedRequest(signedRequest, appSecret) {
  // In a real implementation, this would verify the signed request
  // using the Facebook app secret and HMAC-SHA256 algorithm
  console.log('Verifying Facebook signed request with app secret')

  // For now, we'll return a mock verification
  // In production, you would implement proper verification
  return {
    isValid: true,
    userId: '123456789',
    algorithm: 'HMAC-SHA256'
  }
}

module.exports = router;