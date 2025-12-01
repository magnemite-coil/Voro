// components/common/Button/Button.tsx
import { forwardRef, type ButtonHTMLAttributes, type ReactNode } from 'react';
import clsx from 'clsx';
import { Spinner } from '../Spinner/Spinner';
import styles from './Button.module.css';

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'danger' | 'outline';
  isLoading?: boolean;
  size?: 'small' | 'medium' | 'large';
  children: ReactNode;
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  function Button(
    {
      children,
      variant = 'primary',
      size = 'medium',
      isLoading,
      disabled,
      className,
      ...props
    },
    ref
  ) {
    return (
      <button
        ref={ref}
        className={clsx(
          styles.button,
          styles[variant],
          styles[size],
          isLoading && styles.loading,
          className
        )}
        disabled={disabled || isLoading}
        {...props}
      >
        {isLoading ? <Spinner size="small" /> : children}
      </button>
    );
  }
);
