import { fireEvent, render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { Carousel } from './carousel';

const images = ['one', 'two', 'three'].map((name) => ({
  key: name,
  src: `/${name}.png`,
  alt: name,
}));

const show = (onOpen?: (i: number) => void) =>
  render(<Carousel images={images} label="Images in this post" onOpen={onOpen} />);

const count = () => screen.getByText(/\/ 3$/).textContent;

describe('Carousel', () => {
  it('starts on the first image with nothing before it', () => {
    show();

    expect(count()).toBe('1 / 3');
    expect(screen.getByRole('button', { name: 'Previous image' })).toHaveProperty('disabled', true);
    expect(screen.getByRole('button', { name: 'Next image' })).toHaveProperty('disabled', false);
  });

  it('stops at the last image', () => {
    show();

    const next = screen.getByRole('button', { name: 'Next image' });

    fireEvent.click(next);
    fireEvent.click(next);
    fireEvent.click(next);

    expect(count()).toBe('3 / 3');
    expect(next).toHaveProperty('disabled', true);
  });

  it('moves with the arrow keys, Home and End', () => {
    show();

    const carousel = screen.getByRole('region', { name: 'Images in this post' });

    fireEvent.keyDown(carousel, { key: 'ArrowRight' });
    expect(count()).toBe('2 / 3');

    fireEvent.keyDown(carousel, { key: 'End' });
    expect(count()).toBe('3 / 3');

    fireEvent.keyDown(carousel, { key: 'ArrowLeft' });
    fireEvent.keyDown(carousel, { key: 'Home' });
    expect(count()).toBe('1 / 3');
  });

  it('opens the image that is showing', () => {
    const onOpen = vi.fn();

    show(onOpen);

    fireEvent.click(screen.getByRole('button', { name: 'Next image' }));
    fireEvent.click(screen.getByRole('button', { name: 'Open two' }));

    expect(onOpen).toHaveBeenCalledWith(1);
  });
});
