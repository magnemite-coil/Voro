import { fileURLToPath } from 'url'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  // キャッシュをプロジェクトルートの .cache/vite/ に集約
  // これにより rm -rf .cache/ で全キャッシュをクリア可能
  // ESM では __dirname が使えないため、import.meta.url から導出
  cacheDir: fileURLToPath(new URL('../.cache/vite', import.meta.url)),
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://localhost:8080',
        changeOrigin: true,
      },
    },
  },
})
