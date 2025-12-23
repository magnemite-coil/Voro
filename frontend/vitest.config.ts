// vitest.config.ts
import { coverageConfigDefaults, defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.ts'],
    globals: true,
    coverage: {
      include: ['src/**'],
      exclude: [
        'src/main.tsx',
        'src/types/**',
        'src/test/**',
        ...coverageConfigDefaults.exclude,
      ],
    },
  },
});
