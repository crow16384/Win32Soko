# Build the Trunk WASM app, then serve static files with nginx.

FROM rust:1-bookworm AS builder

RUN rustup target add wasm32-unknown-unknown \
    && apt-get update \
    && apt-get install -y --no-install-recommends binaryen \
    && rm -rf /var/lib/apt/lists/* \
    && cargo install trunk --locked --version 0.21.14

WORKDIR /src
COPY Cargo.toml Cargo.lock Trunk.toml index.html style.css ./
COPY app ./app
COPY core ./core
COPY assets ./assets

RUN trunk build --release

FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /src/dist /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
