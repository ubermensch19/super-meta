/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        canvas: '#0B0B0F',
        surface: '#16161D',
        'surface-high': '#20212B',
        border: '#2E2F3A',
        accent: '#FFA62B', // warm amber
        live: '#FF4D8D', // magenta
        positive: '#39E0A0', // teal
        'brand-a': '#3B7BF6', // logomark blue
        'brand-b': '#8A2BE2', // logomark purple
        ink: {
          DEFAULT: '#F4F4F6',
          2: '#9A9BA6',
          3: '#61626C',
        },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', '-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'sans-serif'],
        mono: ['"JetBrains Mono"', 'ui-monospace', 'SF Mono', 'Menlo', 'monospace'],
      },
      borderRadius: {
        card: '20px',
      },
      transitionTimingFunction: {
        smooth: 'cubic-bezier(0.22, 1, 0.36, 1)',
      },
      maxWidth: {
        page: '1160px',
      },
      keyframes: {
        drift: {
          '0%': { transform: 'translate3d(0,0,0) scale(1)' },
          '100%': { transform: 'translate3d(6vw,5vw,0) scale(1.12)' },
        },
        shimmer: {
          '0%': { backgroundPosition: '0% 50%' },
          '100%': { backgroundPosition: '200% 50%' },
        },
        scan: {
          '0%': { transform: 'translateY(-120%)' },
          '100%': { transform: 'translateY(320%)' },
        },
        marquee: {
          '0%': { transform: 'translateX(0)' },
          '100%': { transform: 'translateX(-50%)' },
        },
        pulseDot: {
          '0%, 100%': { opacity: '1', transform: 'scale(1)' },
          '50%': { opacity: '0.35', transform: 'scale(0.8)' },
        },
      },
      animation: {
        shimmer: 'shimmer 6s linear infinite',
        scan: 'scan 3.4s ease-in-out infinite',
        marquee: 'marquee 26s linear infinite',
        pulseDot: 'pulseDot 1.6s ease-in-out infinite',
      },
    },
  },
  plugins: [],
}
