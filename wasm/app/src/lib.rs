//! Browser shell for Win32 Sokoban: canvas rendering, animation, input, HUD.

use std::cell::RefCell;
use std::rc::Rc;

use sokoban_core::{
    deserialize_sok, pack_name, parse_levels, serialize_sok, Cell, Dir, Game, Level,
    ANIM_PIXELS_PER_STEP, ANIM_STEPS, CELL_COUNT, HEIGHT, MAX_LEVELS, TILE_SIZE, WIDTH,
};
use wasm_bindgen::prelude::*;
use wasm_bindgen::JsCast;
use web_sys::{
    Blob, BlobPropertyBag, CanvasRenderingContext2d, Document, HtmlButtonElement,
    HtmlCanvasElement, HtmlElement, HtmlImageElement, HtmlInputElement, KeyboardEvent,
    PointerEvent, Url,
};

const SCALE: f64 = 2.0;
const CANVAS_W: u32 = (WIDTH as u32) * (TILE_SIZE as u32) * 2;
const CANVAS_H: u32 = (HEIGHT as u32) * (TILE_SIZE as u32) * 2;
const ANIM_MS: f64 = 40.0;
const SWIPE_THRESHOLD: f64 = 30.0;
const STORAGE_KEY: &str = "win32soko_progress";
const COMPLETED_KEY: &str = "win32soko_completed";

#[derive(Clone)]
struct AnimState {
    dir: Dir,
    pushing: bool,
    step: u32,
    from_player: usize,
    box_from: Option<usize>,
    box_to: Option<usize>,
    won: bool,
}

struct App {
    game: Game,
    levels: Vec<Level>,
    ctx: CanvasRenderingContext2d,
    tile_img: HtmlImageElement,
    box_img: HtmlImageElement,
    anim: Option<AnimState>,
    completed: Vec<bool>,
    touch_start: Option<(f64, f64)>,
    last_tick: f64,
    anim_accum: f64,
}

fn window() -> web_sys::Window {
    web_sys::window().expect("no window")
}

fn document() -> Document {
    window().document().expect("no document")
}

fn el<T: JsCast>(id: &str) -> T {
    document()
        .get_element_by_id(id)
        .unwrap_or_else(|| panic!("missing #{id}"))
        .dyn_into::<T>()
        .unwrap_or_else(|_| panic!("bad type #{id}"))
}

fn set_text(id: &str, text: &str) {
    if let Some(node) = document().get_element_by_id(id) {
        node.set_text_content(Some(text));
    }
}

fn show_overlay(id: &str, visible: bool) {
    if let Some(node) = document().get_element_by_id(id) {
        let class = node.class_list();
        let _ = if visible {
            class.remove_1("hidden")
        } else {
            class.add_1("hidden")
        };
    }
}

fn load_image(src: &str) -> Result<HtmlImageElement, JsValue> {
    let img = HtmlImageElement::new()?;
    img.set_src(src);
    Ok(img)
}

async fn wait_image(img: &HtmlImageElement) -> Result<(), JsValue> {
    if img.complete() && img.natural_width() > 0 {
        return Ok(());
    }
    // Prefer decode() so we don't rely on onload closures that can be dropped
    // before the image finishes (common hang on cold caches / Docker).
    let promise = img.decode();
    wasm_bindgen_futures::JsFuture::from(promise)
        .await
        .map_err(|e| JsValue::from(format!("image decode failed: {e:?}")))?;
    Ok(())
}

async fn load_levels_text() -> Result<String, JsValue> {
    let resp_val =
        wasm_bindgen_futures::JsFuture::from(window().fetch_with_str("assets/levels.txt")).await?;
    let resp: web_sys::Response = resp_val.dyn_into()?;
    if !resp.ok() {
        return Err(JsValue::from_str("failed to fetch levels.txt"));
    }
    let text = wasm_bindgen_futures::JsFuture::from(resp.text()?).await?;
    text.as_string()
        .ok_or_else(|| JsValue::from_str("levels not a string"))
}

fn chroma_key_magenta(img: &HtmlImageElement) -> Result<HtmlCanvasElement, JsValue> {
    let canvas = document()
        .create_element("canvas")?
        .dyn_into::<HtmlCanvasElement>()?;
    let w = img.natural_width();
    let h = img.natural_height();
    canvas.set_width(w);
    canvas.set_height(h);
    let ctx = canvas
        .get_context("2d")?
        .unwrap()
        .dyn_into::<CanvasRenderingContext2d>()?;
    ctx.draw_image_with_html_image_element(img, 0.0, 0.0)?;
    let image_data = ctx.get_image_data(0.0, 0.0, w as f64, h as f64)?;
    let mut data = image_data.data();
    for chunk in data.chunks_mut(4) {
        if chunk[0] > 240 && chunk[1] < 20 && chunk[2] > 240 {
            chunk[3] = 0;
        }
    }
    let new_data = web_sys::ImageData::new_with_u8_clamped_array_and_sh(
        wasm_bindgen::Clamped(data.as_slice()),
        w,
        h,
    )?;
    ctx.put_image_data(&new_data, 0.0, 0.0)?;
    Ok(canvas)
}

fn draw_man(
    ctx: &CanvasRenderingContext2d,
    man: &HtmlCanvasElement,
    frame: u32,
    pushing: bool,
    dx: f64,
    dy: f64,
) -> Result<(), JsValue> {
    let col = frame.min(11);
    let row = if pushing { 1.0 } else { 0.0 };
    let sx = (col as f64) * TILE_SIZE as f64;
    let sy = row * TILE_SIZE as f64;
    ctx.draw_image_with_html_canvas_element_and_sw_and_sh_and_dx_and_dy_and_dw_and_dh(
        man,
        sx,
        sy,
        TILE_SIZE as f64,
        TILE_SIZE as f64,
        dx,
        dy,
        TILE_SIZE as f64 * SCALE,
        TILE_SIZE as f64 * SCALE,
    )?;
    Ok(())
}

impl App {
    fn draw_tile_sprite(
        &self,
        img: &HtmlImageElement,
        idx: u8,
        px: f64,
        py: f64,
    ) -> Result<(), JsValue> {
        let sx = (idx as f64) * TILE_SIZE as f64;
        self.ctx
            .draw_image_with_html_image_element_and_sw_and_sh_and_dx_and_dy_and_dw_and_dh(
                img,
                sx,
                0.0,
                TILE_SIZE as f64,
                TILE_SIZE as f64,
                px,
                py,
                TILE_SIZE as f64 * SCALE,
                TILE_SIZE as f64 * SCALE,
            )?;
        Ok(())
    }

    fn draw_ground(&self, cell: Cell, px: f64, py: f64) -> Result<(), JsValue> {
        let under = cell.without_crate();
        let idx = match under {
            Cell::Wall => 0u8,
            Cell::Floor => 1,
            Cell::Target => 2,
            _ => 1,
        };
        self.draw_tile_sprite(&self.tile_img, idx, px, py)
    }

    fn draw_crate_at(&self, on_target: bool, px: f64, py: f64) -> Result<(), JsValue> {
        let idx = if on_target { 1u8 } else { 0 };
        self.draw_tile_sprite(&self.box_img, idx, px, py)
    }

    fn cell_xy(index: usize) -> (f64, f64) {
        let x = (index % WIDTH) as f64 * TILE_SIZE as f64 * SCALE;
        let y = (index / WIDTH) as f64 * TILE_SIZE as f64 * SCALE;
        (x, y)
    }

    fn redraw(&self, man_canvas: &HtmlCanvasElement) -> Result<(), JsValue> {
        self.ctx.set_image_smoothing_enabled(false);
        self.ctx
            .clear_rect(0.0, 0.0, CANVAS_W as f64, CANVAS_H as f64);

        let hide_crate_at = self.anim.as_ref().and_then(|a| a.box_to);

        for i in 0..CELL_COUNT {
            let (px, py) = Self::cell_xy(i);
            let cell = self.game.cells[i];
            self.draw_ground(cell, px, py)?;
            if cell.is_crate() && hide_crate_at != Some(i) {
                self.draw_crate_at(cell == Cell::CrateOnTarget, px, py)?;
            }
        }

        if let Some(a) = &self.anim {
            let (dx, dy) = a.dir.delta();
            let progress = a.step as f64 * ANIM_PIXELS_PER_STEP as f64 * SCALE;
            let (fx, fy) = Self::cell_xy(a.from_player);
            let px = fx + dx as f64 * progress;
            let py = fy + dy as f64 * progress;

            if let (Some(box_from), Some(box_to)) = (a.box_from, a.box_to) {
                let (bx, by) = Self::cell_xy(box_from);
                let bpx = bx + dx as f64 * progress;
                let bpy = by + dy as f64 * progress;
                let on_target = self.game.cells[box_to] == Cell::CrateOnTarget;
                self.draw_crate_at(on_target, bpx, bpy)?;
            }

            let base = a.dir.sprite_base();
            let frame = if a.step > 2 {
                let wobble = 4i32 - a.step as i32;
                (base as i32 + wobble).max(0) as u32
            } else {
                base + a.step
            };
            draw_man(&self.ctx, man_canvas, frame, a.pushing, px, py)?;
        } else {
            let (px, py) = Self::cell_xy(self.game.player);
            draw_man(&self.ctx, man_canvas, 0, false, px, py)?;
        }
        Ok(())
    }

    fn update_hud(&self) {
        set_text("hud-pack", pack_name(self.game.level_index));
        set_text("hud-level", &format!("{}", self.game.level_index + 1));
        set_text("hud-boxes", &format!("{}", self.game.remaining));
        set_text("hud-moves", &format!("{}", self.game.moves));
        if let Some(btn) = document().get_element_by_id("btn-undo") {
            if let Ok(btn) = btn.dyn_into::<HtmlButtonElement>() {
                btn.set_disabled(!self.game.can_undo());
            }
        }
        if let Some(btn) = document().get_element_by_id("btn-redo") {
            if let Ok(btn) = btn.dyn_into::<HtmlButtonElement>() {
                btn.set_disabled(!self.game.can_redo());
            }
        }
    }

    fn save_progress(&self) {
        let bytes = serialize_sok(&self.game);
        let b64 = base64_encode(&bytes);
        if let Ok(Some(storage)) = window().local_storage() {
            let _ = storage.set_item(STORAGE_KEY, &b64);
            let completed: String = self
                .completed
                .iter()
                .map(|c| if *c { '1' } else { '0' })
                .collect();
            let _ = storage.set_item(COMPLETED_KEY, &completed);
        }
    }

    fn load_level(&mut self, index: usize) {
        if index >= self.levels.len() {
            return;
        }
        self.game = Game::new(self.levels[index].clone(), index);
        self.anim = None;
        self.update_hud();
        self.save_progress();
        self.build_level_browser();
    }

    fn try_start_move(&mut self, dir: Dir) -> bool {
        if self.anim.is_some() {
            return false;
        }
        let Some(pushing) = self.game.can_move(dir) else {
            return false;
        };
        let from_player = self.game.player;
        let box_from = if pushing {
            dir.offset_index(from_player)
        } else {
            None
        };
        let box_to = box_from.and_then(|b| dir.offset_index(b));

        let result = match self.game.try_move(dir) {
            Some(r) => r,
            None => return false,
        };
        self.anim = Some(AnimState {
            dir,
            pushing: result.pushing,
            step: 0,
            from_player,
            box_from,
            box_to,
            won: result.won,
        });
        self.anim_accum = 0.0;
        self.update_hud();
        true
    }

    fn finish_anim(&mut self) {
        let won = self.anim.as_ref().map(|a| a.won).unwrap_or(false);
        self.anim = None;
        self.save_progress();
        self.update_hud();
        if won {
            self.completed[self.game.level_index] = true;
            self.save_progress();
            if self.game.level_index + 1 >= MAX_LEVELS {
                set_text("win-title", "Game finished!");
                set_text(
                    "win-body",
                    "Excellent! You are hardworking and clever enough… Thanks for playing this remake of Crow16384's 2004 masterpiece.",
                );
                if let Some(btn) = document().get_element_by_id("btn-next") {
                    btn.set_text_content(Some("Play again"));
                }
            } else {
                set_text("win-title", "Level complete!");
                set_text(
                    "win-body",
                    &format!(
                        "Congratulations! Level {} cleared in {} moves.",
                        self.game.level_index + 1,
                        self.game.moves
                    ),
                );
                if let Some(btn) = document().get_element_by_id("btn-next") {
                    btn.set_text_content(Some("Next level"));
                }
            }
            show_overlay("overlay-win", true);
        }
    }

    /// Returns true when the animation has completed.
    fn tick_anim(&mut self, dt_ms: f64) -> bool {
        if self.anim.is_none() {
            return false;
        }
        self.anim_accum += dt_ms;
        while self.anim_accum >= ANIM_MS {
            self.anim_accum -= ANIM_MS;
            if let Some(anim) = self.anim.as_mut() {
                anim.step += 1;
                if anim.step >= ANIM_STEPS {
                    return true;
                }
            }
        }
        false
    }

    fn build_level_browser(&self) {
        let Some(container) = document().get_element_by_id("level-browser") else {
            return;
        };
        container.set_inner_html("");

        let packs: &[(&str, usize, usize)] = &[
            ("Classic", 0, 50),
            ("Extra", 50, 92),
            ("Yoshio Murase", 92, 138),
        ];

        for (name, start, end) in packs {
            let section = document().create_element("div").unwrap();
            section.set_class_name("pack-section");
            let h3 = document().create_element("h3").unwrap();
            h3.set_text_content(Some(name));
            let grid = document().create_element("div").unwrap();
            grid.set_class_name("level-grid");

            for i in *start..*end {
                let btn = document()
                    .create_element("button")
                    .unwrap()
                    .dyn_into::<HtmlButtonElement>()
                    .unwrap();
                btn.set_type("button");
                btn.set_class_name("level-btn");
                btn.set_text_content(Some(&format!("{}", i + 1)));
                if i == self.game.level_index {
                    let _ = btn.class_list().add_1("current");
                }
                if self.completed.get(i).copied().unwrap_or(false) {
                    let _ = btn.class_list().add_1("done");
                }
                let _ = btn.set_attribute("data-level", &i.to_string());
                let _ = grid.append_child(&btn);
            }
            let _ = section.append_child(&h3);
            let _ = section.append_child(&grid);
            let _ = container.append_child(&section);
        }
    }

    fn export_sok(&self) -> Result<(), JsValue> {
        let bytes = serialize_sok(&self.game);
        let arr = js_sys::Uint8Array::new_with_length(bytes.len() as u32);
        arr.copy_from(&bytes);
        let parts = js_sys::Array::new();
        parts.push(&arr);
        let props = BlobPropertyBag::new();
        props.set_type("application/octet-stream");
        let blob = Blob::new_with_u8_array_sequence_and_options(&parts, &props)?;
        let url = Url::create_object_url_with_blob(&blob)?;
        let a = document()
            .create_element("a")?
            .dyn_into::<web_sys::HtmlAnchorElement>()?;
        a.set_href(&url);
        a.set_download(&format!("level{}.sok", self.game.level_index + 1));
        a.click();
        Url::revoke_object_url(&url)?;
        Ok(())
    }

    fn import_sok_bytes(&mut self, data: &[u8]) -> Result<(), String> {
        let game = deserialize_sok(data, &self.levels)?;
        self.game = game;
        self.anim = None;
        self.update_hud();
        self.save_progress();
        self.build_level_browser();
        Ok(())
    }
}

fn base64_encode(data: &[u8]) -> String {
    let arr = js_sys::Uint8Array::new_with_length(data.len() as u32);
    arr.copy_from(data);
    js_sys::Function::new_with_args(
        "bytes",
        "let s=''; for (let i=0;i<bytes.length;i++) s+=String.fromCharCode(bytes[i]); return btoa(s);",
    )
    .call1(&JsValue::NULL, &arr)
    .ok()
    .and_then(|v| v.as_string())
    .unwrap_or_default()
}

fn base64_decode(s: &str) -> Result<Vec<u8>, JsValue> {
    let bin = js_sys::Function::new_with_args(
        "s",
        "const bin=atob(s); const out=new Uint8Array(bin.length); for (let i=0;i<bin.length;i++) out[i]=bin.charCodeAt(i); return out;",
    )
    .call1(&JsValue::NULL, &JsValue::from_str(s))?;
    let arr = js_sys::Uint8Array::new(&bin);
    let mut bytes = vec![0u8; arr.length() as usize];
    arr.copy_to(&mut bytes);
    Ok(bytes)
}

#[wasm_bindgen(start)]
pub fn main() {
    console_error_panic_hook::set_once();
    wasm_bindgen_futures::spawn_local(async {
        if let Err(e) = boot().await {
            web_sys::console::error_1(&e);
            if let Some(node) = document().get_element_by_id("overlay-loading") {
                let msg = e
                    .as_string()
                    .unwrap_or_else(|| format!("{e:?}"));
                node.set_inner_html(&format!(
                    "<div class=\"modal compact\"><p>Failed to load: {}</p></div>",
                    html_escape(&msg)
                ));
            }
        }
    });
}

fn html_escape(s: &str) -> String {
    s.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
}

async fn boot() -> Result<(), JsValue> {
    let canvas = el::<HtmlCanvasElement>("game");
    canvas.set_width(CANVAS_W);
    canvas.set_height(CANVAS_H);
    let ctx = canvas
        .get_context("2d")?
        .unwrap()
        .dyn_into::<CanvasRenderingContext2d>()?;
    ctx.set_image_smoothing_enabled(false);

    let tile_img = load_image("assets/Tile.png")?;
    let box_img = load_image("assets/Box.png")?;
    let man_raw = load_image("assets/Man.png")?;
    wait_image(&tile_img).await?;
    wait_image(&box_img).await?;
    wait_image(&man_raw).await?;

    let man_canvas = Rc::new(chroma_key_magenta(&man_raw)?);

    let levels_text = load_levels_text().await?;
    let levels = parse_levels(&levels_text).map_err(|e| JsValue::from_str(&e))?;

    let mut completed = vec![false; MAX_LEVELS];
    let mut game = Game::new(levels[0].clone(), 0);

    if let Ok(Some(storage)) = window().local_storage() {
        if let Ok(Some(comp)) = storage.get_item(COMPLETED_KEY) {
            for (i, ch) in comp.chars().enumerate() {
                if i < completed.len() {
                    completed[i] = ch == '1';
                }
            }
        }
        if let Ok(Some(b64)) = storage.get_item(STORAGE_KEY) {
            if let Ok(bytes) = base64_decode(&b64) {
                if let Ok(g) = deserialize_sok(&bytes, &levels) {
                    game = g;
                }
            }
        }
    }

    let app = Rc::new(RefCell::new(App {
        game,
        levels,
        ctx,
        tile_img,
        box_img,
        anim: None,
        completed,
        touch_start: None,
        last_tick: 0.0,
        anim_accum: 0.0,
    }));

    {
        let a = app.borrow();
        a.update_hud();
        a.build_level_browser();
        a.redraw(&man_canvas)?;
    }
    show_overlay("overlay-loading", false);

    wire_events(app.clone(), man_canvas.clone())?;
    start_loop(app, man_canvas)?;
    Ok(())
}

fn wire_events(app: Rc<RefCell<App>>, man_canvas: Rc<HtmlCanvasElement>) -> Result<(), JsValue> {
    {
        let app = app.clone();
        let man = man_canvas.clone();
        let closure = Closure::wrap(Box::new(move |e: KeyboardEvent| {
            let key = e.key();
            let ctrl = e.ctrl_key() || e.meta_key();
            let mut a = app.borrow_mut();

            if ctrl {
                match key.as_str() {
                    "z" | "Z" if e.shift_key() => {
                        e.prevent_default();
                        if a.anim.is_some() {
                            a.anim = None;
                            a.anim_accum = 0.0;
                        }
                        if a.game.redo() {
                            a.update_hud();
                            a.save_progress();
                            let _ = a.redraw(&man);
                        }
                    }
                    "z" | "Z" => {
                        e.prevent_default();
                        if a.anim.is_some() {
                            a.anim = None;
                            a.anim_accum = 0.0;
                        }
                        if a.game.undo() {
                            a.update_hud();
                            a.save_progress();
                            let _ = a.redraw(&man);
                        }
                    }
                    "r" | "R" => {
                        e.prevent_default();
                        if a.anim.is_none() {
                            a.game.restart();
                            a.update_hud();
                            a.save_progress();
                            let _ = a.redraw(&man);
                        }
                    }
                    "n" | "N" => {
                        e.prevent_default();
                        a.load_level(0);
                        let _ = a.redraw(&man);
                    }
                    "s" | "S" => {
                        e.prevent_default();
                        let _ = a.export_sok();
                    }
                    "l" | "L" => {
                        e.prevent_default();
                        el::<HtmlInputElement>("file-import").click();
                    }
                    "d" | "D" => {
                        e.prevent_default();
                        a.build_level_browser();
                        show_overlay("overlay-levels", true);
                    }
                    _ => {}
                }
                return;
            }

            let dir = match key.as_str() {
                "ArrowLeft" => Some(Dir::Left),
                "ArrowRight" => Some(Dir::Right),
                "ArrowUp" => Some(Dir::Up),
                "ArrowDown" => Some(Dir::Down),
                _ => None,
            };
            if let Some(dir) = dir {
                e.prevent_default();
                if a.try_start_move(dir) {
                    let _ = a.redraw(&man);
                }
            }
        }) as Box<dyn FnMut(KeyboardEvent)>);
        // Listen on window so arrow keys work without focusing the canvas.
        window().add_event_listener_with_callback("keydown", closure.as_ref().unchecked_ref())?;
        closure.forget();
    }

    bind_btn("btn-undo", {
        let app = app.clone();
        let man = man_canvas.clone();
        move || {
            let mut a = app.borrow_mut();
            // Cancel in-flight animation so undo always works after a move.
            if a.anim.is_some() {
                a.anim = None;
                a.anim_accum = 0.0;
            }
            if a.game.undo() {
                a.update_hud();
                a.save_progress();
                let _ = a.redraw(&man);
            }
        }
    });
    bind_btn("btn-redo", {
        let app = app.clone();
        let man = man_canvas.clone();
        move || {
            let mut a = app.borrow_mut();
            if a.anim.is_some() {
                a.anim = None;
                a.anim_accum = 0.0;
            }
            if a.game.redo() {
                a.update_hud();
                a.save_progress();
                let _ = a.redraw(&man);
            }
        }
    });
    bind_btn("btn-restart", {
        let app = app.clone();
        let man = man_canvas.clone();
        move || {
            let mut a = app.borrow_mut();
            if a.anim.is_none() {
                a.game.restart();
                a.update_hud();
                a.save_progress();
                let _ = a.redraw(&man);
            }
        }
    });
    bind_btn("btn-levels", {
        let app = app.clone();
        move || {
            app.borrow().build_level_browser();
            show_overlay("overlay-levels", true);
        }
    });
    bind_btn("btn-levels-close", || show_overlay("overlay-levels", false));
    bind_btn("btn-about", || show_overlay("overlay-about", true));
    bind_btn("btn-about-close", || show_overlay("overlay-about", false));
    bind_btn("btn-about-ok", || show_overlay("overlay-about", false));
    bind_btn("btn-export", {
        let app = app.clone();
        move || {
            let _ = app.borrow().export_sok();
        }
    });
    bind_btn("btn-import", || {
        el::<HtmlInputElement>("file-import").click();
    });
    bind_btn("btn-next", {
        let app = app.clone();
        let man = man_canvas.clone();
        move || {
            show_overlay("overlay-win", false);
            let mut a = app.borrow_mut();
            let next = if a.game.level_index + 1 >= MAX_LEVELS {
                0
            } else {
                a.game.level_index + 1
            };
            a.load_level(next);
            let _ = a.redraw(&man);
        }
    });

    {
        let app = app.clone();
        let man = man_canvas.clone();
        let browser = el::<HtmlElement>("level-browser");
        let closure = Closure::wrap(Box::new(move |e: web_sys::MouseEvent| {
            let Some(target) = e.target() else {
                return;
            };
            let Ok(el) = target.dyn_into::<HtmlElement>() else {
                return;
            };
            if let Some(level) = el.get_attribute("data-level") {
                if let Ok(idx) = level.parse::<usize>() {
                    show_overlay("overlay-levels", false);
                    let mut a = app.borrow_mut();
                    a.load_level(idx);
                    let _ = a.redraw(&man);
                }
            }
        }) as Box<dyn FnMut(web_sys::MouseEvent)>);
        browser.add_event_listener_with_callback("click", closure.as_ref().unchecked_ref())?;
        closure.forget();
    }

    {
        let app = app.clone();
        let man = man_canvas.clone();
        let input = el::<HtmlInputElement>("file-import");
        let closure = Closure::wrap(Box::new(move |e: web_sys::Event| {
            let input: HtmlInputElement = e.target().unwrap().dyn_into().unwrap();
            let Some(files) = input.files() else {
                return;
            };
            let Some(file) = files.get(0) else {
                return;
            };
            let reader = web_sys::FileReader::new().unwrap();
            let app = app.clone();
            let man = man.clone();
            let onload = Closure::wrap(Box::new(move |e: web_sys::Event| {
                let reader: web_sys::FileReader = e.target().unwrap().dyn_into().unwrap();
                let Ok(result) = reader.result() else {
                    return;
                };
                let Ok(buf) = result.dyn_into::<js_sys::ArrayBuffer>() else {
                    return;
                };
                let arr = js_sys::Uint8Array::new(&buf);
                let mut bytes = vec![0u8; arr.length() as usize];
                arr.copy_to(&mut bytes);
                let mut a = app.borrow_mut();
                match a.import_sok_bytes(&bytes) {
                    Ok(()) => {
                        let _ = a.redraw(&man);
                    }
                    Err(err) => {
                        web_sys::console::error_1(&JsValue::from_str(&err));
                    }
                }
            }) as Box<dyn FnMut(web_sys::Event)>);
            reader.set_onload(Some(onload.as_ref().unchecked_ref()));
            onload.forget();
            let _ = reader.read_as_array_buffer(&file);
            input.set_value("");
        }) as Box<dyn FnMut(web_sys::Event)>);
        input.add_event_listener_with_callback("change", closure.as_ref().unchecked_ref())?;
        closure.forget();
    }

    {
        let app = app.clone();
        let man = man_canvas.clone();
        let frame = document()
            .query_selector(".board-frame")?
            .unwrap()
            .dyn_into::<HtmlElement>()?;

        let down = Closure::wrap(Box::new({
            let app = app.clone();
            move |e: PointerEvent| {
                app.borrow_mut().touch_start = Some((e.client_x() as f64, e.client_y() as f64));
            }
        }) as Box<dyn FnMut(PointerEvent)>);

        let up = Closure::wrap(Box::new({
            let app = app.clone();
            let man = man.clone();
            move |e: PointerEvent| {
                let mut a = app.borrow_mut();
                let Some((sx, sy)) = a.touch_start.take() else {
                    return;
                };
                let dx = e.client_x() as f64 - sx;
                let dy = e.client_y() as f64 - sy;
                if dx.abs() < SWIPE_THRESHOLD && dy.abs() < SWIPE_THRESHOLD {
                    return;
                }
                let dir = if dx.abs() > dy.abs() {
                    if dx > 0.0 {
                        Dir::Right
                    } else {
                        Dir::Left
                    }
                } else if dy > 0.0 {
                    Dir::Down
                } else {
                    Dir::Up
                };
                if a.try_start_move(dir) {
                    let _ = a.redraw(&man);
                }
            }
        }) as Box<dyn FnMut(PointerEvent)>);

        frame.add_event_listener_with_callback("pointerdown", down.as_ref().unchecked_ref())?;
        frame.add_event_listener_with_callback("pointerup", up.as_ref().unchecked_ref())?;
        down.forget();
        up.forget();
    }

    Ok(())
}

fn bind_btn<F: FnMut() + 'static>(id: &str, mut f: F) {
    let Some(btn) = document().get_element_by_id(id) else {
        return;
    };
    let Ok(btn) = btn.dyn_into::<HtmlButtonElement>() else {
        return;
    };
    let closure = Closure::wrap(Box::new(move || f()) as Box<dyn FnMut()>);
    let _ = btn.add_event_listener_with_callback("click", closure.as_ref().unchecked_ref());
    closure.forget();
}

fn start_loop(app: Rc<RefCell<App>>, man_canvas: Rc<HtmlCanvasElement>) -> Result<(), JsValue> {
    let f = Rc::new(RefCell::new(None::<Closure<dyn FnMut(f64)>>));
    let g = f.clone();

    *g.borrow_mut() = Some(Closure::wrap(Box::new(move |timestamp: f64| {
        {
            let mut a = app.borrow_mut();
            let dt = (timestamp - a.last_tick).clamp(0.0, 100.0);
            a.last_tick = timestamp;
            let finished = a.tick_anim(dt);
            if finished {
                a.finish_anim();
                let _ = a.redraw(&man_canvas);
            } else if a.anim.is_some() {
                let _ = a.redraw(&man_canvas);
            }
        }
        let _ = window()
            .request_animation_frame(f.borrow().as_ref().unwrap().as_ref().unchecked_ref());
    }) as Box<dyn FnMut(f64)>));

    window().request_animation_frame(g.borrow().as_ref().unwrap().as_ref().unchecked_ref())?;
    Ok(())
}
