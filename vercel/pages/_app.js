import '../styles/globals.css'
import { useEffect } from 'react'
import { useRouter } from 'next/router'
import Script from 'next/script'

/**
 * Custom Next.js App component that injects global scripts and initializes the Facebook SDK on mount.
 *
 * Initializes the Facebook JavaScript SDK once when the app mounts and renders the active page with its props.
 *
 * @param {{ Component: import('next').NextPage, pageProps: any }} props - Next.js App props.
 * @param {import('next').NextPage} props.Component - The currently active page component.
 * @param {any} props.pageProps - Props to be passed to the active page component.
 * @returns {JSX.Element} The application wrapper element that renders global scripts and the active page.
 */
function MyApp({ Component, pageProps }) {
  const router = useRouter()

  useEffect(() => {
    // Load Facebook SDK
    const loadFacebookSDK = () => {
      if (window.FB) return

      window.fbAsyncInit = function() {
        FB.init({
          appId: process.env.NEXT_PUBLIC_FACEBOOK_APP_ID,
          cookie: true,
          status: true,
          xfbml: false,
          autoLogAppEvents: true,
          version: process.env.NEXT_PUBLIC_FACEBOOK_API_VERSION || 'v18.0'
        })
      }

      // Load SDK asynchronously
      const script = document.createElement('script')
      script.src = 'https://connect.facebook.net/en_US/sdk.js'
      script.async = true
      script.defer = true
      script.crossOrigin = 'anonymous'
      document.body.appendChild(script)
    }

    loadFacebookSDK()
  }, [])

  return (
    <>
      <Script
        src="https://ajax.googleapis.com/ajax/libs/jquery/3.7.1/jquery.min.js"
        strategy="beforeInteractive"
      />
      <Script
        src="https://ajax.googleapis.com/ajax/libs/jqueryui/1.12.1/jquery-ui.min.js"
        strategy="beforeInteractive"
      />
      <Component {...pageProps} />
    </>
  )
}

export default MyApp