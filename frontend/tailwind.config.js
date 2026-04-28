/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{vue,js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        'phoenix-bg': '#0f172a',
        'phoenix-card': '#1e293b',
        'phoenix-accent': '#38bdf8',
        'phoenix-text': '#f8fafc',
        'phoenix-muted': '#94a3b8',
      },
    },
  },
  plugins: [],
}
