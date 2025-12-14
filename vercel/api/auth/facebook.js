import { NextApiRequest, NextApiResponse } from 'next'

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' })
  }

  try {
    const { authResponse } = req.body

    if (!authResponse) {
      return res.status(400).json({ error: 'Missing authResponse' })
    }

    // In a production environment, you would verify the signed request
    // with your Facebook app secret here

    // For now, we'll just return the user data
    const userData = {
      facebookId: authResponse.userID,
      accessToken: authResponse.accessToken,
      expiresIn: authResponse.expiresIn,
      signedRequest: authResponse.signedRequest
    }

    // Here you would typically:
    // 1. Verify the signed request
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
}

// Helper function to verify Facebook signed request
function verifySignedRequest(signedRequest, appSecret) {
  // This would be implemented in a production environment
  // using the Facebook app secret to verify the signature
  return {
    isValid: true,
    userId: '123456789',
    algorithm: 'HMAC-SHA256'
  }
}