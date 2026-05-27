/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{vue,js,ts,jsx,tsx}"],
  theme: {
    extend: {
      colors: {
        kognisant: {
          bg: "#0f1115", // Darker neutral for professional IDE
          card: "#181a1f", // Translucent-capable neutral
          sidebar: "#1c1e24", // High contrast sidebar
          accent: "#38bdf8", // Primary action color
          muted: "#94a3b8", // Standard muted text
          text: "#f8fafc", // High-readability text
          border: "rgba(255, 255, 255, 0.06)", // Subtle separators
          input: "#090a0d", // Deep contrast for input areas
        },
        syntax: {
          keyword: "#c678dd",
          function: "#61afef",
          string: "#98c379",
          comment: "#5c6370",
          variable: "#e06c75",
        },
      },
      backgroundImage: {
        "vibrant-gradient":
          "linear-gradient(135deg, rgba(56, 189, 248, 0.05) 0%, rgba(15, 17, 21, 0) 100%)",
      },
      borderRadius: {
        xl: "12px",
        "2xl": "16px",
      },
      boxShadow: {
        "agent-panel": "0 20px 50px -12px rgba(0, 0, 0, 0.5)",
        "inner-glow": "inset 0 1px 0 0 rgba(255, 255, 255, 0.05)",
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
