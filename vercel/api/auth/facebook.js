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
  if (!signedRequest || !appSecret) {
    return { isValid: false, error: 'Missing signed request or app secret' }
  }

  try {
    // Split the signed request into signature and payload
    const parts = signedRequest.split('.')
    if (parts.length !== 2) {
      return { isValid: false, error: 'Invalid signed request format' }
    }

    const [encodedSignature, encodedPayload] = parts

    // Decode the signature (base64url to base64, then to buffer)
    const signature = Buffer.from(
      encodedSignature.replace(/-/g, '+').replace(/_/g, '/'),
      'base64'
    )

    // Decode the payload
    const payload = Buffer.from(
      encodedPayload.replace(/-/g, '+').replace(/_/g, '/'),
      'base64'
    ).toString('utf-8')

    // Parse the payload JSON
    const data = JSON.parse(payload)

    // Verify the algorithm
    if (data.algorithm && data.algorithm.toUpperCase() !== 'HMAC-SHA256') {
      return { isValid: false, error: 'Unsupported algorithm: ' + data.algorithm }
    }

    // Calculate expected signature using HMAC-SHA256
    const crypto = require('crypto')
    const expectedSignature = crypto
      .createHmac('sha256', appSecret)
      .update(encodedPayload)
      .digest()

    // Compare signatures using timing-safe comparison
    if (!crypto.timingSafeEqual(signature, expectedSignature)) {
      return { isValid: false, error: 'Signature verification failed' }
    }

    return {
      isValid: true,
      userId: data.user_id,
      algorithm: 'HMAC-SHA256',
      data: data
    }
  } catch (error) {
    console.error('Error verifying signed request:', error.message)
    return { isValid: false, error: 'Verification error: ' + error.message }
  }
}

module.exports = router;