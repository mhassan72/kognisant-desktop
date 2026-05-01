/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{vue,js,ts,jsx,tsx}"],
  theme: {
    extend: {
      colors: {
        "kognisant-bg": "#0f172a",
        "kognisant-card": "#1e293b",
        "kognisant-accent": "#38bdf8",
        "kognisant-text": "#f8fafc",
        "kognisant-muted": "#94a3b8",
      },
    },
  },
  plugins: [],
};
