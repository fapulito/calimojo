import Head from 'next/head'
import { useEffect, useState } from 'react'
import styles from '../styles/Home.module.css'
import dynamic from 'next/dynamic'

// Dynamically import poker components to avoid SSR issues
const PokerMain = dynamic(() => import('../components/PokerMain'), {
  ssr: false,
  loading: () => <div className={styles.loading}>Loading poker interface...</div>
})

/**
 * Render the Mojo Poker home page and show a loading state until the Facebook SDK and client-side game component are ready.
 *
 * On mount, polls for the Facebook SDK and updates local state to control whether the client-only PokerMain component is rendered or a loading UI is shown.
 * @returns {JSX.Element} The rendered home page element.
 */
export default function Home() {
  const [isLoaded, setIsLoaded] = useState(false)
  const [facebookLoaded, setFacebookLoaded] = useState(false)

  useEffect(() => {
    // Check if Facebook SDK is loaded
    const checkFacebook = () => {
      if (window.FB) {
        setFacebookLoaded(true)
      } else {
        setTimeout(checkFacebook, 100)
      }
    }

    checkFacebook()

    // Mark as loaded
    setIsLoaded(true)
  }, [])

  return (
    <div className={styles.container}>
      <Head>
        <title>Mojo Poker - Play with Friends</title>
        <meta name="description" content="Play poker with friends using Facebook login" />
        <meta property="fb:app_id" content={process.env.NEXT_PUBLIC_FACEBOOK_APP_ID} />
        <meta property="og:url" content="https://mojopoker.vercel.app" />
        <meta property="og:type" content="website" />
        <meta property="og:title" content="Mojo Poker - Play with Friends" />
        <meta property="og:description" content="Chat and play poker with friends" />
        <meta property="og:image" content="https://mojopoker.vercel.app/img/SCREENSHOT.png" />
        <link rel="icon" href="/favicon.png" />
      </Head>

      <main className={styles.main}>
        {isLoaded && facebookLoaded ? (
          <PokerMain />
        ) : (
          <div className={styles.loading}>
            <h2>Loading Mojo Poker...</h2>
            <p>Initializing Facebook integration and game interface...</p>
            <div className={styles.spinner}></div>
          </div>
        )}
      </main>

      <footer className={styles.footer}>
        <div className={styles.footerContent}>
          <a href="/privacy" target="_blank" rel="noopener noreferrer">Privacy Policy</a>
          <a href="/terms" target="_blank" rel="noopener noreferrer">Terms and Conditions</a>
          <a href="https://www.facebook.com" target="_blank" rel="noopener noreferrer">Contact</a>
        </div>
        <div className={styles.copyright}>
          © {new Date().getFullYear()} Mojo Poker. All rights reserved.
        </div>
      </footer>
    </div>
  )
}