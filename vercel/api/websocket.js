import { NextApiRequest, NextApiResponse } from 'next'
import { WebSocketServer } from 'ws'

// WebSocket server instance
let wss

export default function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' })
  }

  // Handle WebSocket upgrade
  if (req.headers.upgrade === 'websocket') {
    return handleWebSocket(req, res)
  }

  // For HTTP requests, return information
  return res.status(200).json({
    message: 'WebSocket endpoint',
    status: 'active',
    supportedProtocols: ['poker-v1']
  })
}

function handleWebSocket(req: NextApiRequest, res: NextApiResponse) {
  // Initialize WebSocket server if not already done
  if (!wss) {
    wss = new WebSocketServer({ noServer: true })

    wss.on('connection', (ws, req) => {
      console.log('New WebSocket connection')

      ws.on('message', (message) => {
        console.log('Received:', message.toString())
        // Handle poker game messages here
      })

      ws.on('close', () => {
        console.log('WebSocket connection closed')
      })

      ws.on('error', (error) => {
        console.error('WebSocket error:', error)
      })
    })
  }

  // Upgrade the connection
  wss.handleUpgrade(req, res.socket, Buffer.alloc(0), (ws) => {
    wss.emit('connection', ws, req)
  })
}

// WebSocket client for connecting to backend
export function createWebSocketClient(url: string) {
  return new Promise((resolve, reject) => {
    try {
      const ws = new WebSocket(url)

      ws.onopen = () => {
        console.log('WebSocket connection established')
        resolve(ws)
      }

      ws.onerror = (error) => {
        console.error('WebSocket error:', error)
        reject(error)
      }

      ws.onclose = () => {
        console.log('WebSocket connection closed')
      }

    } catch (error) {
      console.error('WebSocket creation error:', error)
      reject(error)
    }
  })
}