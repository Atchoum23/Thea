import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
  ],
  build: {
    // Samsung Tizen WebView target
    target: 'es2020',
    outDir: 'dist',
    // Relative paths for file:// loading on Tizen
    base: './',
  },
  base: './',
})
