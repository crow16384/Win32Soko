# Win32 Sokoban (Rust / WASM)

Browser remake of the 2004 MASM32 Sokoban by Crow16384. Original ASM sources stay at the repo root; this folder is the new web build.

## Requirements

- Rust toolchain with `wasm32-unknown-unknown`
- [Trunk](https://trunkrs.dev/) (`cargo install trunk`)

```bash
rustup target add wasm32-unknown-unknown
cargo install trunk
```

## Run

```bash
cd wasm
trunk serve
```

Open http://127.0.0.1:8080/

## Docker

Build and run a production image that serves the static Trunk output with nginx:

```bash
cd wasm
docker compose up --build
```

Or without Compose:

```bash
docker build -t win32soko-wasm .
docker run --rm -p 8080:80 win32soko-wasm
```

Then open http://127.0.0.1:8080/

## Controls

- Arrow keys or swipe on the board to move
- Undo / Redo (Ctrl+Z / Ctrl+Shift+Z)
- Restart (Ctrl+R), New game (Ctrl+N)
- Levels browser (Ctrl+D)
- Export / Import `.sok` saves (Ctrl+S / Ctrl+L)

Progress autosaves to `localStorage`.

## Layout

- `core/` — pure Rust game logic and `.sok` (de)serialization
- `app/` — WASM UI, canvas rendering, input
- `assets/` — original sprites + extracted `levels.txt` (138 levels)
