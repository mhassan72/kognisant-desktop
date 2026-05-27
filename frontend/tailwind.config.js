/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{vue,js,ts,jsx,tsx}"],
  darkMode: "class",
  theme: {
    extend: {
      colors: {
        kognisant: {
          // Brand Colors
          primary: "#706fd3",
          "primary-hover": "#5b59b3",

          // Dark Theme (Requested: #2f3640)
          dark: {
            bg: "#2f3640",
            sidebar: "#252b33",
            card: "#353d48",
            border: "rgba(255, 255, 255, 0.08)",
            text: "#f5f6fa",
            muted: "#8c94a1",
            input: "#21272f",
          },

          // Light Theme (Requested: #f5f6fa)
          light: {
            bg: "#f5f6fa",
            sidebar: "#ffffff",
            card: "#ffffff",
            border: "rgba(47, 54, 64, 0.1)",
            text: "#2f3640",
            muted: "#7f8c8d",
            input: "#e8eaed",
          },

          // Semantic Aliases (Mapped to Dark by default for IDE look)
          bg: "#2f3640",
          card: "#353d48",
          sidebar: "#252b33",
          accent: "#706fd3",
          text: "#f5f6fa",
          muted: "#8c94a1",
          border: "rgba(255, 255, 255, 0.08)",
          input: "#21272f",
        },
        syntax: {
          keyword: "#706fd3",
          function: "#487eb0",
          string: "#44bd32",
          comment: "#7f8c8d",
          variable: "#e84118",
        },
      },
      borderRadius: {
        xl: "8px",
        "2xl": "12px",
      },
      boxShadow: {
        "flat-sm": "0 2px 4px rgba(0, 0, 0, 0.1)",
        "flat-md": "0 4px 6px rgba(0, 0, 0, 0.1)",
      },
      fontSize: {
        xxs: "0.625rem",
      },
      fontFamily: {
        mono: ["JetBrains Mono", "Fira Code", "ui-monospace", "monospace"],
        sans: ["Inter", "system-ui", "sans-serif"],
      },
    },
  },
  plugins: [],
};
