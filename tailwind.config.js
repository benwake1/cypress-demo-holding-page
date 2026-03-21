/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./public/**/*.html'],
  theme: {
    extend: {
      colors: {
        'cyber-green': '#04C38E',
        'cyber-green-dark': '#03A87A',
        'dark': {
          DEFAULT: '#09090C',
          card: '#111116',
          raised: '#17171D',
          border: '#222229',
        },
        'muted': '#888896',
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', '-apple-system', 'sans-serif'],
        mono: ['JetBrains Mono', 'ui-monospace', 'Menlo', 'monospace'],
      },
      backgroundImage: {
        'dot-grid': 'radial-gradient(circle, #ffffff0d 1px, transparent 1px)',
        'hero-glow': 'radial-gradient(ellipse 80% 50% at 50% -10%, #04C38E22, transparent)',
      },
      backgroundSize: {
        'dot-grid': '28px 28px',
      },
      animation: {
        'blink': 'blink 1s step-end infinite',
        'fade-up': 'fadeUp 0.6s ease-out both',
      },
      keyframes: {
        blink: {
          '0%, 100%': { opacity: '1' },
          '50%': { opacity: '0' },
        },
        fadeUp: {
          '0%': { opacity: '0', transform: 'translateY(16px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
      },
    },
  },
  plugins: [],
}
