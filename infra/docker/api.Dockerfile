# Build from the repo root

ARG ELIXIR_VERSION=1.20.4
ARG OTP_VERSION=29.0.5
ARG DEBIAN_VERSION=bookworm-20260824-slim

FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION} AS build

RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential git ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
ENV MIX_ENV=prod \
  HEX_HTTP_TIMEOUT=120

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
COPY apps/hearth/mix.exs apps/hearth/
COPY apps/hearth_web/mix.exs apps/hearth_web/
COPY apps/secrets/mix.exs apps/secrets/
COPY config config
RUN mix deps.get --only prod && mix deps.compile

COPY apps apps
COPY rel rel
# Share cards build the web app's mark into the release
COPY web/public/icon-192.png web/public/icon-192.png

RUN mix compile \
  && cd apps/hearth_web && mix assets.setup && mix assets.deploy && cd ../.. \
  && mix release hearth

FROM debian:${DEBIAN_VERSION}

# vix brings libvips, which still needs the C++ runtime and fontconfig settings
# libsctp is loaded at boot and curl answers the health check
# ffmpeg converts videos, assembles recordings and reads audio for transcripts
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    libstdc++6 fontconfig-config openssl libncurses6 libsctp1 ca-certificates curl ffmpeg \
  && rm -rf /var/lib/apt/lists/*

# Without a UTF-8 locale the VM reads file names as latin1
ENV LANG=C.UTF-8 \
  LC_ALL=C.UTF-8 \
  MIX_ENV=prod \
  PORT=4000 \
  STORAGE_PATH=/data/storage

RUN useradd --create-home --uid 1000 hearth \
  && mkdir -p /data/storage && chown -R hearth:hearth /data

WORKDIR /app
COPY --from=build --chown=hearth:hearth /app/_build/prod/rel/hearth ./
COPY --chmod=755 infra/docker/unset-blank.sh /usr/local/bin/unset-blank
USER hearth

EXPOSE 4000
HEALTHCHECK --interval=10s --timeout=3s --start-period=30s --retries=3 \
  CMD curl -fsS http://localhost:4000/healthz/live || exit 1

ENTRYPOINT ["/usr/local/bin/unset-blank"]
CMD ["/app/bin/server"]
