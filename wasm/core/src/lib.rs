//! Sokoban game logic ported from the 2004 Win32 MASM original.
//!
//! Board is a fixed 20×16 (320-cell) grid. Level data uses the original
//! ASCII encoding: `@` wall, ` ` floor, `x` target, `o` box, `#` box on
//! target, `$` player, `+` player on target.

pub const WIDTH: usize = 20;
pub const HEIGHT: usize = 16;
pub const CELL_COUNT: usize = WIDTH * HEIGHT;
pub const MAX_LEVELS: usize = 138;
pub const TILE_SIZE: i32 = 32;
pub const ANIM_STEPS: u32 = 4;
pub const ANIM_PIXELS_PER_STEP: i32 = 8;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Cell {
    Wall,
    Floor,
    Target,
    Crate,
    CrateOnTarget,
}

impl Cell {
    pub fn is_walkable(self) -> bool {
        matches!(self, Cell::Floor | Cell::Target)
    }

    pub fn is_crate(self) -> bool {
        matches!(self, Cell::Crate | Cell::CrateOnTarget)
    }

    pub fn is_target(self) -> bool {
        matches!(self, Cell::Target | Cell::CrateOnTarget)
    }

    /// Floor under a crate, or the cell itself if empty.
    pub fn without_crate(self) -> Cell {
        match self {
            Cell::Crate => Cell::Floor,
            Cell::CrateOnTarget => Cell::Target,
            other => other,
        }
    }

    pub fn with_crate(self) -> Option<Cell> {
        match self {
            Cell::Floor => Some(Cell::Crate),
            Cell::Target => Some(Cell::CrateOnTarget),
            _ => None,
        }
    }

    pub fn to_char(self) -> char {
        match self {
            Cell::Wall => '@',
            Cell::Floor => ' ',
            Cell::Target => 'x',
            Cell::Crate => 'o',
            Cell::CrateOnTarget => '#',
        }
    }

    pub fn from_char(c: char) -> Option<Cell> {
        match c {
            '@' => Some(Cell::Wall),
            ' ' => Some(Cell::Floor),
            'x' => Some(Cell::Target),
            'o' => Some(Cell::Crate),
            '#' => Some(Cell::CrateOnTarget),
            '$' => Some(Cell::Floor), // player on floor
            '+' => Some(Cell::Target), // player on target
            _ => None,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Dir {
    Left,
    Right,
    Up,
    Down,
}

impl Dir {
    pub fn delta(self) -> (i32, i32) {
        match self {
            Dir::Left => (-1, 0),
            Dir::Right => (1, 0),
            Dir::Up => (0, -1),
            Dir::Down => (0, 1),
        }
    }

    /// Sprite column base matching original Direction equates (0/3/6/9).
    pub fn sprite_base(self) -> u32 {
        match self {
            Dir::Left => 0,
            Dir::Right => 3,
            Dir::Up => 6,
            Dir::Down => 9,
        }
    }

    pub fn offset_index(self, from: usize) -> Option<usize> {
        let (dx, dy) = self.delta();
        let x = (from % WIDTH) as i32 + dx;
        let y = (from / WIDTH) as i32 + dy;
        if x < 0 || y < 0 || x >= WIDTH as i32 || y >= HEIGHT as i32 {
            return None;
        }
        Some((y as usize) * WIDTH + (x as usize))
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Snapshot {
    pub cells: [Cell; CELL_COUNT],
    pub player: usize,
    pub remaining: u16,
    pub moves: u32,
    pub level_index: usize,
}

#[derive(Clone, Debug)]
pub struct Level {
    /// Raw cells with player already stripped (`$`/`+` → floor/target).
    pub cells: [Cell; CELL_COUNT],
    pub player: usize,
    pub remaining: u16,
}

#[derive(Clone, Debug)]
pub struct Game {
    pub cells: [Cell; CELL_COUNT],
    pub player: usize,
    pub remaining: u16,
    pub moves: u32,
    pub level_index: usize,
    undo: Vec<Snapshot>,
    redo: Vec<Snapshot>,
    /// Template used by restart.
    initial: Level,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct MoveResult {
    pub pushing: bool,
    pub won: bool,
}

impl Game {
    pub fn new(level: Level, level_index: usize) -> Self {
        Self {
            cells: level.cells,
            player: level.player,
            remaining: level.remaining,
            moves: 0,
            level_index,
            undo: Vec::new(),
            redo: Vec::new(),
            initial: level,
        }
    }

    pub fn snapshot(&self) -> Snapshot {
        Snapshot {
            cells: self.cells,
            player: self.player,
            remaining: self.remaining,
            moves: self.moves,
            level_index: self.level_index,
        }
    }

    fn restore(&mut self, snap: Snapshot) {
        self.cells = snap.cells;
        self.player = snap.player;
        self.remaining = snap.remaining;
        self.moves = snap.moves;
        self.level_index = snap.level_index;
    }

    pub fn can_undo(&self) -> bool {
        !self.undo.is_empty()
    }

    pub fn can_redo(&self) -> bool {
        !self.redo.is_empty()
    }

    pub fn undo(&mut self) -> bool {
        let Some(prev) = self.undo.pop() else {
            return false;
        };
        self.redo.push(self.snapshot());
        self.restore(prev);
        true
    }

    pub fn redo(&mut self) -> bool {
        let Some(next) = self.redo.pop() else {
            return false;
        };
        self.undo.push(self.snapshot());
        self.restore(next);
        true
    }

    pub fn restart(&mut self) {
        self.cells = self.initial.cells;
        self.player = self.initial.player;
        self.remaining = self.initial.remaining;
        self.moves = 0;
        self.undo.clear();
        self.redo.clear();
    }

    pub fn is_won(&self) -> bool {
        self.remaining == 0
    }

    /// Check whether a move is legal without mutating state.
    pub fn can_move(&self, dir: Dir) -> Option<bool> {
        let next = dir.offset_index(self.player)?;
        let cell = self.cells[next];
        if cell.is_walkable() {
            return Some(false); // walk, not push
        }
        if cell.is_crate() {
            let beyond = dir.offset_index(next)?;
            if self.cells[beyond].is_walkable() {
                return Some(true); // push
            }
        }
        None
    }

    /// Apply a move. Returns `None` if illegal. On success, pushes undo.
    pub fn try_move(&mut self, dir: Dir) -> Option<MoveResult> {
        let pushing = self.can_move(dir)?;
        let snap = self.snapshot();
        let next = dir.offset_index(self.player).unwrap();

        if pushing {
            let beyond = dir.offset_index(next).unwrap();
            let crate_cell = self.cells[next];
            // Remove crate from current cell
            self.cells[next] = crate_cell.without_crate();
            if crate_cell == Cell::CrateOnTarget {
                self.remaining += 1;
            }
            // Place crate on destination
            let dest = self.cells[beyond];
            self.cells[beyond] = dest.with_crate().unwrap();
            if dest == Cell::Target {
                self.remaining -= 1;
            }
        }

        self.player = next;
        self.moves += 1;
        self.undo.push(snap);
        self.redo.clear();

        Some(MoveResult {
            pushing,
            won: self.is_won(),
        })
    }

    pub fn player_xy(&self) -> (i32, i32) {
        (
            (self.player % WIDTH) as i32,
            (self.player / WIDTH) as i32,
        )
    }
}

/// Parse a single 16×20 level from ASCII lines (may include `$`/`+`).
pub fn parse_level(text: &str) -> Result<Level, String> {
    let lines: Vec<&str> = text
        .lines()
        .map(|l| l.trim_end_matches('\r'))
        .filter(|l| !l.starts_with(';') && !l.is_empty())
        .collect();

    if lines.len() != HEIGHT {
        return Err(format!(
            "expected {} rows, got {}",
            HEIGHT,
            lines.len()
        ));
    }

    let mut cells = [Cell::Wall; CELL_COUNT];
    let mut player = None;
    let mut remaining = 0u16;

    for (y, line) in lines.iter().enumerate() {
        let chars: Vec<char> = line.chars().collect();
        if chars.len() != WIDTH {
            return Err(format!(
                "row {y}: expected {WIDTH} cols, got {}",
                chars.len()
            ));
        }
        for (x, &c) in chars.iter().enumerate() {
            let idx = y * WIDTH + x;
            match c {
                '$' => {
                    cells[idx] = Cell::Floor;
                    if player.replace(idx).is_some() {
                        return Err("multiple players".into());
                    }
                }
                '+' => {
                    cells[idx] = Cell::Target;
                    if player.replace(idx).is_some() {
                        return Err("multiple players".into());
                    }
                }
                other => {
                    let cell = Cell::from_char(other)
                        .ok_or_else(|| format!("bad char {other:?} at {x},{y}"))?;
                    cells[idx] = cell;
                    if cell == Cell::Crate {
                        remaining += 1;
                    }
                }
            }
        }
    }

    let player = player.ok_or_else(|| "no player".to_string())?;
    Ok(Level {
        cells,
        player,
        remaining,
    })
}

/// Parse all levels from `levels.txt` (`;Level N` blocks of 16 rows).
pub fn parse_levels(text: &str) -> Result<Vec<Level>, String> {
    let mut levels = Vec::new();
    let mut current: Vec<String> = Vec::new();

    for line in text.lines() {
        let line = line.trim_end_matches('\r');
        if line.starts_with(';') {
            if !current.is_empty() {
                levels.push(parse_level(&current.join("\n"))?);
                current.clear();
            }
            continue;
        }
        if line.is_empty() {
            continue;
        }
        current.push(line.to_string());
        if current.len() == HEIGHT {
            levels.push(parse_level(&current.join("\n"))?);
            current.clear();
        }
    }

    if !current.is_empty() {
        levels.push(parse_level(&current.join("\n"))?);
    }

    if levels.len() != MAX_LEVELS {
        return Err(format!(
            "expected {MAX_LEVELS} levels, got {}",
            levels.len()
        ));
    }
    Ok(levels)
}

pub fn pack_name(level_index: usize) -> &'static str {
    match level_index {
        0..=49 => "Classic",
        50..=91 => "Extra",
        _ => "Yoshio Murase",
    }
}

/// Original `.sok` binary: 320 map bytes + 4×u32 LE (level, player offset, remaining, moves).
pub fn serialize_sok(game: &Game) -> Vec<u8> {
    let mut buf = Vec::with_capacity(CELL_COUNT + 16);
    for cell in &game.cells {
        buf.push(cell.to_char() as u8);
    }
    buf.extend_from_slice(&(game.level_index as u32).to_le_bytes());
    buf.extend_from_slice(&(game.player as u32).to_le_bytes());
    buf.extend_from_slice(&(game.remaining as u32).to_le_bytes());
    buf.extend_from_slice(&game.moves.to_le_bytes());
    buf
}

pub fn deserialize_sok(data: &[u8], templates: &[Level]) -> Result<Game, String> {
    if data.len() < CELL_COUNT + 16 {
        return Err(format!("file too short: {} bytes", data.len()));
    }

    let mut cells = [Cell::Wall; CELL_COUNT];
    for (i, &b) in data[..CELL_COUNT].iter().enumerate() {
        cells[i] = Cell::from_char(b as char)
            .ok_or_else(|| format!("bad map byte {b:#x} at {i}"))?;
        // Player should not be in saved map (original strips it), but be defensive.
        if b == b'$' || b == b'+' {
            cells[i] = if b == b'+' {
                Cell::Target
            } else {
                Cell::Floor
            };
        }
    }

    let level_index = u32::from_le_bytes(data[CELL_COUNT..CELL_COUNT + 4].try_into().unwrap())
        as usize;
    let player = u32::from_le_bytes(data[CELL_COUNT + 4..CELL_COUNT + 8].try_into().unwrap())
        as usize;
    let remaining =
        u32::from_le_bytes(data[CELL_COUNT + 8..CELL_COUNT + 12].try_into().unwrap()) as u16;
    let moves = u32::from_le_bytes(data[CELL_COUNT + 12..CELL_COUNT + 16].try_into().unwrap());

    if level_index >= templates.len() {
        return Err(format!("level index {level_index} out of range"));
    }
    if player >= CELL_COUNT {
        return Err(format!("player offset {player} out of range"));
    }

    let mut game = Game::new(templates[level_index].clone(), level_index);
    game.cells = cells;
    game.player = player;
    game.remaining = remaining;
    game.moves = moves;
    Ok(game)
}

#[cfg(test)]
mod tests {
    use super::*;

    const TINY: &str = "\
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@  @@@@@@@@@@@
@@@@@@@ o$x@@@@@@@@@
@@@@@@@  @@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@";

    #[test]
    fn parse_and_push_win() {
        let level = parse_level(
            "\
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@  @@@@@@@@@@@
@@@@@@@ $ox@@@@@@@@@
@@@@@@@  @@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@",
        )
        .unwrap();
        let mut game = Game::new(level, 0);
        assert_eq!(game.remaining, 1);
        let r = game.try_move(Dir::Right).unwrap();
        assert!(r.pushing);
        assert!(r.won);
        assert_eq!(game.remaining, 0);
        assert_eq!(game.moves, 1);
    }

    #[test]
    fn undo_redo() {
        let level = parse_level(
            "\
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@  @@@@@@@@@@@
@@@@@@@ $  @@@@@@@@@
@@@@@@@  @@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@",
        )
        .unwrap();
        let mut game = Game::new(level, 0);
        let start = game.player;
        game.try_move(Dir::Right).unwrap();
        assert_ne!(game.player, start);
        assert!(game.undo());
        assert_eq!(game.player, start);
        assert!(game.redo());
        assert_ne!(game.player, start);
    }

    #[test]
    fn blocked_by_wall() {
        let level = parse_level(
            "\
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@  @@@@@@@@@@@
@@@@@@@ $@ @@@@@@@@@
@@@@@@@  @@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@",
        )
        .unwrap();
        let mut game = Game::new(level, 0);
        assert!(game.try_move(Dir::Right).is_none());
    }

    #[test]
    fn sok_roundtrip() {
        let level = parse_level(TINY).unwrap();
        let mut game = Game::new(level.clone(), 5);
        game.try_move(Dir::Left); // may or may not work
        let bytes = serialize_sok(&game);
        assert_eq!(bytes.len(), 336);
        let templates = vec![level; 10];
        let loaded = deserialize_sok(&bytes, &templates).unwrap();
        assert_eq!(loaded.level_index, 5);
        assert_eq!(loaded.player, game.player);
        assert_eq!(loaded.moves, game.moves);
        assert_eq!(loaded.cells, game.cells);
    }

    #[test]
    fn pack_names() {
        assert_eq!(pack_name(0), "Classic");
        assert_eq!(pack_name(49), "Classic");
        assert_eq!(pack_name(50), "Extra");
        assert_eq!(pack_name(91), "Extra");
        assert_eq!(pack_name(92), "Yoshio Murase");
        assert_eq!(pack_name(137), "Yoshio Murase");
    }

    #[test]
    fn parse_all_bundled_levels() {
        let text = include_str!("../../assets/levels.txt");
        let levels = parse_levels(text).expect("parse all levels");
        assert_eq!(levels.len(), MAX_LEVELS);
        assert!(levels[0].remaining > 0);
        assert!(levels[92].remaining > 0);
        assert!(levels[137].remaining > 0);
    }
}
