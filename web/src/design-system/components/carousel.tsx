import { useRef, useState, type CSSProperties, type KeyboardEvent } from 'react';
import { Icon } from '@/design-system/icons/Icon';
import { IconButton } from './button';
import { Img } from './image';
import './carousel.css';

export type CarouselImage = {
  readonly key: string;
  readonly src: string;
  readonly alt: string;
  readonly width?: number | undefined;
  readonly height?: number | undefined;
};

export function Carousel({
  images,
  label,
  onOpen,
}: {
  readonly images: readonly CarouselImage[];
  readonly label: string;
  readonly onOpen?: ((index: number) => void) | undefined;
}) {
  const track = useRef<HTMLDivElement>(null);
  const [index, setIndex] = useState(0);
  const last = images.length - 1;
  const first = images[0];

  const go = (next: number) => {
    const to = Math.max(0, Math.min(last, next));

    setIndex(to);

    const el = track.current;

    el?.scrollTo?.({ left: to * el.clientWidth });
  };

  const followScroll = () => {
    const el = track.current;
    if (!el || !el.clientWidth) return;

    setIndex(Math.max(0, Math.min(last, Math.round(el.scrollLeft / el.clientWidth))));
  };

  const onKeyDown = (e: KeyboardEvent) => {
    if (e.key === 'ArrowRight') go(index + 1);
    else if (e.key === 'ArrowLeft') go(index - 1);
    else if (e.key === 'Home') go(0);
    else if (e.key === 'End') go(last);
    else return;

    e.preventDefault();
  };

  if (!first) return null;

  const ratio = first.width && first.height ? `${first.width} / ${first.height}` : '4 / 3';

  return (
    <section
      className="carousel"
      aria-roledescription="carousel"
      aria-label={label}
      tabIndex={0}
      onKeyDown={onKeyDown}
      style={{ '--carousel-ratio': ratio } as CSSProperties}
    >
      <div className="carousel__track" ref={track} onScroll={followScroll}>
        {images.map((image, i) => (
          <div
            key={image.key}
            className="carousel__slide"
            role="group"
            aria-roledescription="slide"
            aria-label={`${i + 1} of ${images.length}`}
            aria-hidden={i !== index}
          >
            <Img className="carousel__backdrop" src={image.src} alt="" lazy={i !== 0} />
            {onOpen ? (
              <button
                type="button"
                className="carousel__open"
                tabIndex={i === index ? 0 : -1}
                aria-label={'Open ' + image.alt}
                onClick={() => onOpen(i)}
              >
                <Img
                  className="carousel__image"
                  src={image.src}
                  alt={image.alt}
                  width={image.width}
                  height={image.height}
                  lazy={i !== 0}
                />
              </button>
            ) : (
              <Img
                className="carousel__image"
                src={image.src}
                alt={image.alt}
                width={image.width}
                height={image.height}
                lazy={i !== 0}
              />
            )}
          </div>
        ))}
      </div>

      <IconButton
        size="small"
        className="carousel__prev"
        aria-label="Previous image"
        disabled={index === 0}
        onClick={() => go(index - 1)}
      >
        <Icon name="chevron" />
      </IconButton>
      <IconButton
        size="small"
        className="carousel__next"
        aria-label="Next image"
        disabled={index === last}
        onClick={() => go(index + 1)}
      >
        <Icon name="chevron" />
      </IconButton>

      <span className="carousel__count" aria-live="polite">
        {index + 1} / {images.length}
      </span>
      <span className="carousel__dots" aria-hidden="true">
        {images.map((image, i) => (
          <i key={image.key} className={i === index ? 'is-current' : undefined} />
        ))}
      </span>
    </section>
  );
}
