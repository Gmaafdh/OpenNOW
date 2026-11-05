use std::collections::VecDeque;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};

use opennow_streamer_protocol::{NativeOverlay, NativeOverlayItem};

#[derive(Debug, Clone, Copy, Default, PartialEq)]
pub struct NativeOverlayRect {
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
}

impl NativeOverlayRect {
    pub const fn contains(self, x: f32, y: f32) -> bool {
        x >= self.x && y >= self.y && x < self.x + self.width && y < self.y + self.height
    }

    const fn center(self) -> (f32, f32) {
        (self.x + self.width / 2.0, self.y + self.height / 2.0)
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct NativeOverlayPlacement {
    pub index: usize,
    pub rect: NativeOverlayRect,
}

#[derive(Debug, Clone, Default, PartialEq)]
pub struct NativeOverlayLayout {
    pub panel: Option<NativeOverlayRect>,
    pub summary: Option<NativeOverlayRect>,
    pub footer: Option<NativeOverlayRect>,
    pub items: Vec<NativeOverlayPlacement>,
    pub hud: Vec<NativeOverlayPlacement>,
    pub scrim: bool,
    pub compact: bool,
    pub scale: f32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NativeOverlayDirection {
    Up,
    Down,
    Left,
    Right,
}

#[derive(Debug, Clone)]
pub struct NativeOverlaySnapshot {
    pub view: NativeOverlay,
    pub width: u32,
    pub height: u32,
    pub dpi_scale: f32,
    pub focused: Option<usize>,
    pub hovered: Option<usize>,
    pub pressed: Option<usize>,
    pub generation: u64,
    pub transition: u64,
    pub presentation_available: bool,
    pressed_action: Option<String>,
}

impl Default for NativeOverlaySnapshot {
    fn default() -> Self {
        Self {
            view: NativeOverlay::default(),
            width: 1280,
            height: 720,
            dpi_scale: 1.0,
            focused: None,
            hovered: None,
            pressed: None,
            generation: 0,
            transition: 0,
            presentation_available: true,
            pressed_action: None,
        }
    }
}

impl NativeOverlaySnapshot {
    pub fn layout(&self) -> NativeOverlayLayout {
        layout_native_overlay(&self.view, self.width, self.height, self.dpi_scale)
    }

    pub fn modal(&self) -> bool {
        self.presentation_available && !self.view.kind.is_empty() && self.view.input_blocking
    }
}

#[derive(Debug)]
pub struct NativeOverlayShared {
    state: Mutex<NativeOverlaySnapshot>,
    actions: Mutex<VecDeque<String>>,
    presentation_available: AtomicBool,
}

impl Default for NativeOverlayShared {
    fn default() -> Self {
        Self {
            state: Mutex::new(NativeOverlaySnapshot::default()),
            actions: Mutex::new(VecDeque::new()),
            presentation_available: AtomicBool::new(true),
        }
    }
}

impl NativeOverlayShared {
    pub fn new() -> Arc<Self> {
        Arc::new(Self::default())
    }

    pub fn snapshot(&self) -> NativeOverlaySnapshot {
        let available = self.presentation_available.load(Ordering::Acquire);
        let mut snapshot = self
            .state
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
            .clone();
        snapshot.presentation_available = available;
        if !available {
            // QML owns the fallback overlay in this state. Never let invisible
            // native geometry capture game input while presentation is absent.
            snapshot.view = NativeOverlay::default();
            snapshot.focused = None;
            snapshot.hovered = None;
            snapshot.pressed = None;
            snapshot.pressed_action = None;
        }
        snapshot
    }

    pub(crate) fn render_state(&self) -> (bool, u64, u64, bool) {
        let state = self
            .state
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        (
            !state.view.kind.is_empty() || !state.view.hud.is_empty(),
            state.generation,
            state.transition,
            state.view.reduced_motion,
        )
    }

    pub fn presentation_available(&self) -> bool {
        self.presentation_available.load(Ordering::Acquire)
    }

    pub fn set_presentation_available(&self, available: bool) {
        self.presentation_available
            .store(available, Ordering::Release);
        if !available {
            self.release_pointer();
            self.actions
                .lock()
                .unwrap_or_else(std::sync::PoisonError::into_inner)
                .clear();
        }
    }

    /// Queue a shell action independently of gameplay-input readiness. The
    /// output pump turns this into media feedback before NVST can clear its
    /// gameplay queue. A bound prevents repeated controller/mouse activation
    /// from growing without limit while the shell is busy.
    pub fn enqueue_action(&self, action: String) -> bool {
        if !self.presentation_available() || action.trim().is_empty() {
            return false;
        }
        let mut actions = self
            .actions
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        if actions.len() >= 32 {
            return false;
        }
        actions.push_back(action);
        true
    }

    pub fn take_action(&self) -> Option<String> {
        if !self.presentation_available() {
            return None;
        }
        self.actions
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
            .pop_front()
    }

    pub fn set_viewport(&self, width: u32, height: u32, dpi_scale: f32) {
        let mut state = self
            .state
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        let width = width.max(2);
        let height = height.max(2);
        let dpi_scale = finite_clamp(dpi_scale, 0.75, 3.0, 1.0);
        if (state.width, state.height, state.dpi_scale) == (width, height, dpi_scale) {
            return;
        }
        state.width = width;
        state.height = height;
        state.dpi_scale = dpi_scale;
        state.generation = state.generation.wrapping_add(1);
    }

    pub fn update_view(&self, mut view: NativeOverlay) {
        if !matches!(view.kind.as_str(), "" | "menu" | "stats" | "exit") {
            view = NativeOverlay::default();
        }
        // Statistics and HUD-only models are deliberately passive. Only the
        // menu and exit dialog may take modal ownership of gameplay input.
        view.input_blocking = matches!(view.kind.as_str(), "menu" | "exit") && view.input_blocking;
        view.items.truncate(64);
        view.summary.truncate(3);
        view.hud.truncate(16);
        let mut state = self
            .state
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        let previous_focus = state
            .focused
            .and_then(|index| state.view.items.get(index).map(|item| item.id.clone()));
        let kind_changed = state.view.kind != view.kind || state.view.expanded != view.expanded;
        state.view = view;
        state.generation = state.generation.wrapping_add(1);
        if kind_changed {
            state.transition = state.transition.wrapping_add(1);
            state.hovered = None;
            state.pressed = None;
            state.pressed_action = None;
        }
        state.focused = previous_focus
            .as_deref()
            .and_then(|id| {
                state
                    .view
                    .items
                    .iter()
                    .position(|item| item.id == id && focusable(item))
            })
            .or_else(|| first_focusable(&state.view.items));
        if state.focused.is_none() && kind_changed {
            state.focused = first_focusable(&state.view.items);
        }
    }

    pub fn clear(&self) {
        self.update_view(NativeOverlay::default());
        self.actions
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
            .clear();
    }

    pub fn move_focus(&self, direction: NativeOverlayDirection) -> bool {
        if !self.presentation_available() {
            return false;
        }
        let mut state = self
            .state
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        let layout = state.layout();
        let candidates = layout
            .items
            .iter()
            .filter(|placement| state.view.items.get(placement.index).is_some_and(focusable))
            .collect::<Vec<_>>();
        if candidates.is_empty() {
            state.focused = None;
            return false;
        }
        let Some(current) = state
            .focused
            .and_then(|index| candidates.iter().find(|placement| placement.index == index))
        else {
            state.focused = Some(candidates[0].index);
            return true;
        };
        let (cx, cy) = current.rect.center();
        let mut best: Option<(usize, f32)> = None;
        for candidate in &candidates {
            if candidate.index == current.index {
                continue;
            }
            let (x, y) = candidate.rect.center();
            let (primary, cross) = match direction {
                NativeOverlayDirection::Up if y < cy - 1.0 => (cy - y, (x - cx).abs()),
                NativeOverlayDirection::Down if y > cy + 1.0 => (y - cy, (x - cx).abs()),
                NativeOverlayDirection::Left if x < cx - 1.0 => (cx - x, (y - cy).abs()),
                NativeOverlayDirection::Right if x > cx + 1.0 => (x - cx, (y - cy).abs()),
                _ => continue,
            };
            let score = primary + cross * 3.0;
            if best.is_none_or(|(_, previous)| score < previous) {
                best = Some((candidate.index, score));
            }
        }
        // Linear wrap keeps a two-column grid and a single-column dialog usable
        // without trapping controller focus at an edge.
        let target = best.map(|(index, _)| index).or_else(|| {
            let position = candidates
                .iter()
                .position(|placement| placement.index == current.index)?;
            let next = match direction {
                NativeOverlayDirection::Up | NativeOverlayDirection::Left => {
                    (position + candidates.len() - 1) % candidates.len()
                }
                NativeOverlayDirection::Down | NativeOverlayDirection::Right => {
                    (position + 1) % candidates.len()
                }
            };
            Some(candidates[next].index)
        });
        let changed = target != state.focused && target.is_some();
        state.focused = target;
        state.hovered = None;
        if changed {
            state.generation = state.generation.wrapping_add(1);
        }
        changed
    }

    pub fn activate_focused(&self) -> Option<String> {
        if !self.presentation_available() {
            return None;
        }
        let state = self
            .state
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        if let Some(action) = state
            .focused
            .and_then(|index| state.view.items.get(index))
            .and_then(action_for_item)
        {
            return Some(action);
        }
        nonempty_action(&state.view.panel_action)
    }

    pub fn cancel(&self) -> Option<String> {
        if !self.presentation_available() {
            return None;
        }
        let state = self
            .state
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        (!state.view.kind.is_empty()).then(|| "dismiss-overlay".to_owned())
    }

    /// Returns true when the native UI owns this pointer event. Passive HUD
    /// pixels remain game input; modal menu/dialog pixels never reach the game.
    pub fn pointer_move(&self, x: f32, y: f32) -> bool {
        if !self.presentation_available() {
            return false;
        }
        let mut state = self
            .state
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        let layout = state.layout();
        let hovered = layout.items.iter().find_map(|placement| {
            let item = state.view.items.get(placement.index)?;
            (placement.rect.contains(x, y) && focusable(item)).then_some(placement.index)
        });
        if state.hovered != hovered {
            state.generation = state.generation.wrapping_add(1);
        }
        state.hovered = hovered;
        state.pressed = None;
        if let Some(index) = hovered {
            state.focused = Some(index);
        }
        state.modal() || action_at(&state.view, &layout, x, y).is_some()
    }

    pub fn pointer_down(&self, x: f32, y: f32) -> bool {
        if !self.presentation_available() {
            return false;
        }
        let mut state = self
            .state
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        let layout = state.layout();
        let action = action_at(&state.view, &layout, x, y);
        state.pressed_action = action;
        let pressed = layout.items.iter().find_map(|placement| {
            let item = state.view.items.get(placement.index)?;
            (placement.rect.contains(x, y) && focusable(item)).then_some(placement.index)
        });
        if state.pressed != pressed {
            state.generation = state.generation.wrapping_add(1);
        }
        state.pressed = pressed;
        if let Some(index) = state.pressed {
            state.focused = Some(index);
        }
        state.modal() || state.pressed_action.is_some()
    }

    pub fn pointer_up(&self, x: f32, y: f32) -> Option<String> {
        if !self.presentation_available() {
            return None;
        }
        let mut state = self
            .state
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        let layout = state.layout();
        let current = action_at(&state.view, &layout, x, y);
        let pressed = state.pressed_action.take();
        if state.pressed.take().is_some() {
            state.generation = state.generation.wrapping_add(1);
        }
        (pressed.is_some() && pressed == current)
            .then_some(current)
            .flatten()
    }

    pub fn release_pointer(&self) {
        let mut state = self
            .state
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        state.pressed = None;
        state.pressed_action = None;
        state.hovered = None;
    }
}

fn finite_clamp(value: f32, minimum: f32, maximum: f32, fallback: f32) -> f32 {
    if value.is_finite() {
        value.clamp(minimum, maximum)
    } else {
        fallback
    }
}

fn focusable(item: &NativeOverlayItem) -> bool {
    item.enabled && !item.action.trim().is_empty()
}

fn first_focusable(items: &[NativeOverlayItem]) -> Option<usize> {
    items.iter().position(focusable)
}

fn action_for_item(item: &NativeOverlayItem) -> Option<String> {
    focusable(item).then(|| item.action.trim().to_owned())
}

fn nonempty_action(action: &str) -> Option<String> {
    let action = action.trim();
    (!action.is_empty()).then(|| action.to_owned())
}

fn action_at(view: &NativeOverlay, layout: &NativeOverlayLayout, x: f32, y: f32) -> Option<String> {
    for placement in &layout.items {
        if placement.rect.contains(x, y) {
            if let Some(action) = view.items.get(placement.index).and_then(action_for_item) {
                return Some(action);
            }
        }
    }
    if layout.panel.is_some_and(|panel| panel.contains(x, y)) {
        if let Some(action) = nonempty_action(&view.panel_action) {
            return Some(action);
        }
    }
    if view.input_blocking
        && matches!(view.kind.as_str(), "menu" | "exit")
        && layout.panel.is_some_and(|panel| !panel.contains(x, y))
    {
        return Some("dismiss-overlay".to_owned());
    }
    None
}

pub fn layout_native_overlay(
    view: &NativeOverlay,
    width: u32,
    height: u32,
    dpi_scale: f32,
) -> NativeOverlayLayout {
    let width = width.max(2) as f32;
    let height = height.max(2) as f32;
    let scale = finite_clamp(dpi_scale, 0.75, 3.0, 1.0) * finite_clamp(view.scale, 0.85, 1.5, 1.0);
    let mut layout = NativeOverlayLayout {
        scale,
        ..NativeOverlayLayout::default()
    };
    match view.kind.as_str() {
        "menu" => layout_menu(view, width, height, &mut layout),
        "stats" => layout_stats(view, width, height, &mut layout),
        "exit" => layout_exit(view, width, height, &mut layout),
        _ => {}
    }
    layout_hud(view, width, scale, &mut layout);
    layout
}

fn layout_menu(view: &NativeOverlay, width: f32, height: f32, layout: &mut NativeOverlayLayout) {
    let s = layout.scale;
    let compact = height / s < 720.0;
    layout.compact = compact;
    let margin = if compact { 12.0 } else { 16.0 } * s;
    let panel = NativeOverlayRect {
        x: margin,
        y: margin,
        width: (456.0 * s).min((width - 2.0 * margin).max(160.0)),
        height: (height - 2.0 * margin).max(240.0),
    };
    layout.panel = Some(panel);
    layout.scrim = true;
    let inset = if compact { 16.0 } else { 20.0 } * s;
    let content_x = panel.x + inset;
    let content_width = (panel.width - 2.0 * inset).max(80.0);
    let header = if compact { 104.0 } else { 116.0 } * s;
    let footer_height = if view.footer.trim().is_empty() {
        0.0
    } else if compact {
        26.0 * s
    } else {
        34.0 * s
    };
    let footer_y = panel.y + panel.height - footer_height;
    let bottom = footer_y - if footer_height > 0.0 { 8.0 * s } else { 0.0 };
    if footer_height > 0.0 {
        layout.footer = Some(NativeOverlayRect {
            x: content_x,
            y: footer_y,
            width: content_width,
            height: footer_height,
        });
    }
    let spacing = if compact { 7.0 } else { 9.0 } * s;
    let gap = if compact { 8.0 } else { 10.0 } * s;
    let mut y = panel.y + header;
    if !view.summary.is_empty() {
        let summary_height = if compact { 80.0 } else { 94.0 } * s;
        layout.summary = Some(NativeOverlayRect {
            x: content_x,
            y,
            width: content_width,
            height: summary_height,
        });
        y += summary_height + spacing;
    }
    let mut index = 0_usize;
    while index < view.items.len() {
        let item = &view.items[index];
        let role = item.role.as_str();
        let item_height = match (role, compact) {
            ("primary", true) => 44.0 * s,
            ("primary", false) => 50.0 * s,
            ("toggle", true) => 60.0 * s,
            ("toggle", false) => 78.0 * s,
            ("metric", true) => 40.0 * s,
            ("metric", false) => 48.0 * s,
            (_, true) => 46.0 * s,
            (_, false) => 56.0 * s,
        };
        if y + item_height > bottom {
            break;
        }
        if role == "toggle"
            && view
                .items
                .get(index + 1)
                .is_some_and(|next| next.role == "toggle")
        {
            let item_width = (content_width - gap) / 2.0;
            for column in 0..2 {
                layout.items.push(NativeOverlayPlacement {
                    index: index + column,
                    rect: NativeOverlayRect {
                        x: content_x + column as f32 * (item_width + gap),
                        y,
                        width: item_width,
                        height: item_height,
                    },
                });
            }
            index += 2;
        } else {
            layout.items.push(NativeOverlayPlacement {
                index,
                rect: NativeOverlayRect {
                    x: content_x,
                    y,
                    width: content_width,
                    height: item_height,
                },
            });
            index += 1;
        }
        y += item_height + spacing;
    }
}

fn layout_stats(view: &NativeOverlay, width: f32, height: f32, layout: &mut NativeOverlayLayout) {
    let s = layout.scale;
    let margin = 24.0 * s;
    let columns = if view.expanded { 2 } else { 3 };
    let rows = view.items.len().max(1).div_ceil(columns);
    let panel_width =
        ((if view.expanded { 720.0 } else { 620.0 }) * s).min((width - 2.0 * margin).max(240.0));
    let desired_height = if view.expanded {
        (146.0 + rows as f32 * 56.0) * s
    } else {
        (104.0 + rows as f32 * 42.0) * s
    };
    let panel_height = desired_height.min((height - 2.0 * margin).max(140.0));
    let right = view.position.ends_with("right") || view.position.is_empty();
    let bottom = view.position.starts_with("bottom");
    let panel = NativeOverlayRect {
        x: if right {
            width - panel_width - margin
        } else {
            margin
        },
        y: if bottom {
            height - panel_height - margin
        } else {
            margin
        },
        width: panel_width,
        height: panel_height,
    };
    layout.panel = Some(panel);
    let inset = 18.0 * s;
    let header = if view.expanded { 126.0 * s } else { 88.0 * s };
    let gap = 10.0 * s;
    let item_width = (panel.width - 2.0 * inset - gap * (columns - 1) as f32) / columns as f32;
    let item_height = if view.expanded { 48.0 * s } else { 34.0 * s };
    for (index, _) in view.items.iter().enumerate() {
        let row = index / columns;
        let column = index % columns;
        let y = panel.y + header + row as f32 * (item_height + gap);
        if y + item_height > panel.y + panel.height - inset {
            break;
        }
        layout.items.push(NativeOverlayPlacement {
            index,
            rect: NativeOverlayRect {
                x: panel.x + inset + column as f32 * (item_width + gap),
                y,
                width: item_width,
                height: item_height,
            },
        });
    }
}

fn layout_exit(view: &NativeOverlay, width: f32, height: f32, layout: &mut NativeOverlayLayout) {
    let s = layout.scale;
    let panel_width = (520.0 * s).min((width - 48.0 * s).max(240.0));
    let panel_height = (268.0 * s).min((height - 48.0 * s).max(220.0));
    let panel = NativeOverlayRect {
        x: (width - panel_width) / 2.0,
        y: (height - panel_height) / 2.0,
        width: panel_width,
        height: panel_height,
    };
    layout.panel = Some(panel);
    layout.scrim = true;
    let inset = 28.0 * s;
    let gap = 10.0 * s;
    let count = view.items.len().clamp(1, 2) as f32;
    let item_width = (panel.width - 2.0 * inset - gap * (count - 1.0)) / count;
    for (index, _) in view.items.iter().take(2).enumerate() {
        layout.items.push(NativeOverlayPlacement {
            index,
            rect: NativeOverlayRect {
                x: panel.x + inset + index as f32 * (item_width + gap),
                y: panel.y + panel.height - inset - 48.0 * s,
                width: item_width,
                height: 48.0 * s,
            },
        });
    }
}

fn layout_hud(view: &NativeOverlay, width: f32, scale: f32, layout: &mut NativeOverlayLayout) {
    let margin = 24.0 * scale;
    let hud_top = if view.kind == "stats" && !view.position.starts_with("bottom") {
        layout
            .panel
            .map(|panel| panel.y + panel.height + 12.0 * scale)
            .unwrap_or(margin)
    } else {
        margin
    };
    let mut left = margin;
    let mut right = width - margin;
    let mut toast_y = hud_top;
    for (index, item) in view.hud.iter().enumerate() {
        let role = item.role.as_str();
        let toast = role == "toast";
        let item_width = if toast {
            (384.0 * scale).min((width - 2.0 * margin).max(180.0))
        } else {
            ((item.label.chars().count().max(8) as f32 * 7.5 + 32.0) * scale)
                .min((width * 0.42).max(96.0))
        };
        let item_height = if toast { 76.0 * scale } else { 36.0 * scale };
        let (x, y) = match role {
            "hud-left" => {
                let x = left;
                left += item_width + 10.0 * scale;
                (x, hud_top)
            }
            "toast" => {
                let x = width - margin - item_width;
                let y = toast_y;
                toast_y += item_height + 10.0 * scale;
                (x, y)
            }
            _ => {
                right -= item_width;
                let x = right;
                right -= 10.0 * scale;
                (x, hud_top)
            }
        };
        layout.hud.push(NativeOverlayPlacement {
            index,
            rect: NativeOverlayRect {
                x,
                y,
                width: item_width,
                height: item_height,
            },
        });
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn item(id: &str, action: &str, role: &str) -> NativeOverlayItem {
        NativeOverlayItem {
            id: id.to_owned(),
            action: action.to_owned(),
            label: id.to_owned(),
            role: role.to_owned(),
            ..NativeOverlayItem::default()
        }
    }

    fn menu() -> NativeOverlay {
        NativeOverlay {
            kind: "menu".to_owned(),
            input_blocking: true,
            items: vec![
                item("resume", "dismiss-overlay", "primary"),
                item("mic", "toggle-microphone", "toggle"),
                item("afk", "toggle-anti-afk", "toggle"),
                item("stats", "show-stats-expanded", "toggle"),
                item("fullscreen", "toggle-fullscreen", "toggle"),
                item("end", "stop-stream", "danger"),
            ],
            ..NativeOverlay::default()
        }
    }

    #[test]
    fn menu_layout_and_hit_testing_share_physical_coordinates() {
        let shared = NativeOverlayShared::new();
        shared.set_viewport(1920, 1080, 1.5);
        shared.update_view(menu());
        let snapshot = shared.snapshot();
        let layout = snapshot.layout();
        assert_eq!(layout.scale, 1.5);
        let first = layout.items[0].rect;
        assert!(shared.pointer_down(first.x + first.width / 2.0, first.y + first.height / 2.0));
        assert_eq!(
            shared.pointer_up(first.x + first.width / 2.0, first.y + first.height / 2.0),
            Some("dismiss-overlay".to_owned())
        );
        assert!(shared.pointer_down(1800.0, 800.0));
        assert_eq!(
            shared.pointer_up(1800.0, 800.0),
            Some("dismiss-overlay".to_owned())
        );
    }

    #[test]
    fn passive_stats_capture_only_their_panel() {
        let shared = NativeOverlayShared::new();
        shared.set_viewport(1280, 720, 1.0);
        shared.update_view(NativeOverlay {
            kind: "stats".to_owned(),
            panel_action: "toggle-stats".to_owned(),
            items: vec![NativeOverlayItem {
                label: "60 fps".to_owned(),
                role: "metric".to_owned(),
                enabled: false,
                ..NativeOverlayItem::default()
            }],
            ..NativeOverlay::default()
        });
        let panel = shared.snapshot().layout().panel.expect("stats panel");
        assert!(!shared.pointer_down(20.0, 700.0));
        assert!(shared.pointer_down(panel.x + 4.0, panel.y + 4.0));
        assert_eq!(
            shared.pointer_up(panel.x + 4.0, panel.y + 4.0),
            Some("toggle-stats".to_owned())
        );
    }

    #[test]
    fn focus_navigation_wraps_and_telemetry_preserves_item_identity() {
        let shared = NativeOverlayShared::new();
        shared.update_view(menu());
        assert_eq!(shared.snapshot().focused, Some(0));
        assert!(shared.move_focus(NativeOverlayDirection::Up));
        assert_eq!(shared.snapshot().focused, Some(5));
        assert!(shared.move_focus(NativeOverlayDirection::Down));
        assert_eq!(shared.snapshot().focused, Some(0));
        shared.move_focus(NativeOverlayDirection::Down);
        let focused = shared.snapshot().focused.expect("focused item");
        let id = shared.snapshot().view.items[focused].id.clone();
        let mut updated = menu();
        updated.subtitle = "new telemetry".to_owned();
        shared.update_view(updated);
        let focused = shared.snapshot().focused.expect("retained focus");
        assert_eq!(shared.snapshot().view.items[focused].id, id);
    }

    #[test]
    fn hud_does_not_steal_gameplay_input() {
        let shared = NativeOverlayShared::new();
        shared.update_view(NativeOverlay {
            hud: vec![NativeOverlayItem {
                label: "ANTI-AFK ON".to_owned(),
                role: "hud-left".to_owned(),
                enabled: false,
                ..NativeOverlayItem::default()
            }],
            ..NativeOverlay::default()
        });
        let pill = shared.snapshot().layout().hud[0].rect;
        assert!(!shared.pointer_down(pill.x + 2.0, pill.y + 2.0));
        assert_eq!(shared.cancel(), None);
    }

    #[test]
    fn compact_menu_keeps_all_actions_at_minimum_size() {
        let mut view = menu();
        view.items.insert(
            5,
            NativeOverlayItem {
                label: "Controllers".to_owned(),
                role: "row".to_owned(),
                enabled: false,
                ..NativeOverlayItem::default()
            },
        );
        view.items
            .insert(6, item("console", "toggle-console-mode", "row"));
        let layout = layout_native_overlay(&view, 960, 540, 1.0);
        assert!(layout.compact);
        assert_eq!(layout.items.len(), view.items.len());
        let panel = layout.panel.expect("menu panel");
        assert!(
            layout
                .items
                .iter()
                .all(|item| { item.rect.y + item.rect.height <= panel.y + panel.height })
        );
    }

    #[test]
    fn top_stats_pushes_hud_and_toasts_below_the_panel() {
        let view = NativeOverlay {
            kind: "stats".to_owned(),
            position: "top-right".to_owned(),
            items: vec![NativeOverlayItem {
                label: "60 fps".to_owned(),
                role: "metric".to_owned(),
                enabled: false,
                ..NativeOverlayItem::default()
            }],
            hud: vec![NativeOverlayItem {
                label: "00:10:00".to_owned(),
                role: "hud-right".to_owned(),
                enabled: false,
                ..NativeOverlayItem::default()
            }],
            ..NativeOverlay::default()
        };
        let layout = layout_native_overlay(&view, 1280, 720, 1.0);
        let panel = layout.panel.expect("stats panel");
        assert!(
            layout
                .hud
                .iter()
                .all(|item| item.rect.y >= panel.y + panel.height)
        );
    }

    #[test]
    fn passive_or_unknown_views_cannot_trap_gameplay_input() {
        let shared = NativeOverlayShared::new();
        shared.update_view(NativeOverlay {
            kind: "stats".to_owned(),
            input_blocking: true,
            ..NativeOverlay::default()
        });
        assert!(!shared.snapshot().modal());
        shared.update_view(NativeOverlay {
            kind: "unknown-panel".to_owned(),
            input_blocking: true,
            ..NativeOverlay::default()
        });
        assert!(shared.snapshot().view.kind.is_empty());
        assert!(!shared.snapshot().modal());
        assert_eq!(shared.cancel(), None);
    }

    #[test]
    fn unavailable_presentation_disables_hit_testing_without_losing_the_view() {
        let shared = NativeOverlayShared::new();
        shared.update_view(menu());
        assert!(shared.snapshot().modal());
        shared.set_presentation_available(false);
        assert!(shared.snapshot().view.kind.is_empty());
        assert!(!shared.snapshot().modal());
        assert!(!shared.pointer_down(40.0, 180.0));
        assert_eq!(shared.activate_focused(), None);
        shared.set_presentation_available(true);
        assert_eq!(shared.snapshot().view.kind, "menu");
        assert!(shared.snapshot().modal());
    }

    #[test]
    fn exit_dialog_has_two_native_actions() {
        let shared = NativeOverlayShared::new();
        shared.update_view(NativeOverlay {
            kind: "exit".to_owned(),
            input_blocking: true,
            items: vec![
                item("keep", "dismiss-overlay", "primary"),
                item("confirm", "confirm-stream-exit", "danger"),
            ],
            ..NativeOverlay::default()
        });
        assert_eq!(
            shared.activate_focused(),
            Some("dismiss-overlay".to_owned())
        );
        shared.move_focus(NativeOverlayDirection::Right);
        assert_eq!(
            shared.activate_focused(),
            Some("confirm-stream-exit".to_owned())
        );
    }

    #[test]
    fn native_actions_are_bounded_and_cleared_with_presentation() {
        let shared = NativeOverlayShared::new();
        shared.update_view(menu());
        assert!(!shared.enqueue_action("  ".to_owned()));
        assert!(shared.enqueue_action("dismiss-overlay".to_owned()));
        for _ in 0..31 {
            assert!(shared.enqueue_action("toggle-stats".to_owned()));
        }
        assert!(!shared.enqueue_action("stop-stream".to_owned()));
        shared.set_presentation_available(false);
        assert_eq!(shared.take_action(), None);
        shared.set_presentation_available(true);
        assert!(shared.enqueue_action("dismiss-overlay".to_owned()));
        assert_eq!(shared.take_action(), Some("dismiss-overlay".to_owned()));
        assert_eq!(shared.take_action(), None);
    }

    #[test]
    fn rich_menu_keeps_summary_controls_and_footer_inside_panel() {
        let mut view = menu();
        view.footer = "Esc Back · Ctrl G Menu".to_owned();
        view.summary = vec![
            item("fps", "", "metric"),
            item("output", "", "metric"),
            item("bitrate", "", "metric"),
        ];
        view.items.splice(
            5..5,
            [
                item("clipboard", "toggle-clipboard-paste", "toggle"),
                item("cursor", "toggle-pointer-lock", "toggle"),
                NativeOverlayItem {
                    label: "Controllers".to_owned(),
                    role: "row".to_owned(),
                    enabled: false,
                    ..NativeOverlayItem::default()
                },
                item("console", "toggle-console-mode", "row"),
            ],
        );
        let layout = layout_native_overlay(&view, 1600, 900, 1.0);
        assert!(layout.summary.is_some());
        assert!(layout.footer.is_some());
        assert_eq!(layout.items.len(), view.items.len());
        let panel = layout.panel.expect("menu panel");
        assert!(
            layout
                .items
                .iter()
                .all(|item| { item.rect.y + item.rect.height <= panel.y + panel.height })
        );
    }
}
