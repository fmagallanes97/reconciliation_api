FROM elixir:1.18-alpine

RUN apk add --no-cache build-base git

ENV MIX_ENV=prod

RUN mix local.hex --force && \
    mix local.rebar --force

WORKDIR /app

COPY mix.exs mix.lock ./
COPY config ./config
RUN mix deps.get --only $MIX_ENV

COPY . .

RUN mix deps.compile && \
    mix compile && \
    mix release

COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]
