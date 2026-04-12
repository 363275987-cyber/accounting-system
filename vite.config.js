import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  base: process.env.GITHUB_PAGES ? '/accounting-system/' : (process.env.VERCEL || process.env.COS_DEPLOY || process.env.NETLIFY) ? '/' : '/billiard-ledger/',
  plugins: [vue(), tailwindcss()],
  server: {
    host: '0.0.0.0',
    port: 5175,
  },
})
