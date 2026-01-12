// components/post/StatsCard/StatsCard.test.tsx
import { render, screen } from '@testing-library/react';
import { describe, it, expect } from 'vitest';
import { StatsCard } from './StatsCard';

describe('StatsCard', () => {
  it('renders label and value', () => {
    render(<StatsCard label="総記事数" value={42} />);

    expect(screen.getByText('総記事数')).toBeInTheDocument();
    expect(screen.getByText('42')).toBeInTheDocument();
  });

  it('formats large numbers with locale', () => {
    render(<StatsCard label="閲覧数" value={1234567} />);

    // toLocaleString() で桁区切り
    expect(screen.getByText('1,234,567')).toBeInTheDocument();
  });

  it('displays zero correctly', () => {
    render(<StatsCard label="下書き" value={0} />);

    expect(screen.getByText('下書き')).toBeInTheDocument();
    expect(screen.getByText('0')).toBeInTheDocument();
  });
});
