import { AmbientBackground } from './components/AmbientBackground'
import { Nav } from './components/Nav'
import { Hero } from './components/Hero'
import { TrustStrip } from './components/TrustStrip'
import { VisionShowcase } from './components/VisionShowcase'
import { Features } from './components/Features'
import { Providers } from './components/Providers'
import { HowItWorks } from './components/HowItWorks'
import { Specs } from './components/Specs'
import { CTA } from './components/CTA'
import { Footer } from './components/Footer'

export default function App() {
  return (
    <>
      <AmbientBackground />
      <Nav />
      <main>
        <Hero />
        <TrustStrip />
        <VisionShowcase />
        <Features />
        <Providers />
        <HowItWorks />
        <Specs />
        <CTA />
      </main>
      <Footer />
    </>
  )
}
