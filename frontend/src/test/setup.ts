// test/setup.ts
import '@testing-library/jest-dom/vitest';

// jsdom未実装のwindow.scrollToをモック
window.scrollTo = () => {};
