import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  base: '/admin/',  // 设置base路径为/admin/
  server: { port: 5174 },
  resolve: {
    alias: {
      '@rabby/shared': path.resolve(__dirname, '../../packages/shared'),
    },
  },
});
