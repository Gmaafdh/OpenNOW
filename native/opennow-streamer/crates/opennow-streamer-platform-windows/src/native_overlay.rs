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
    /// Scrollable menu-content viewport. App-bar actions live outside it.
    pub content: Option<NativeOverlayRect>,
    pub items: Vec<NativeOverlayPlacement>,
    pub hud: Vec<NativeOverlayPlacement>,
    pub scrim: bool,
    pub compact: bool,
    pub scale: f32,
    pub scroll_offset: f32,
    pub max_scroll: f32,
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
    scroll_offset: f32,
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
            scroll_offset: 0.0,
        }
    }
}

impl NativeOverlaySnapshot {
    pub fn layout(&self) -> NativeOverlayLayout {
        layout_native_overlay_at(
            &self.view,
            self.width,
            self.height,
            self.dpi_scale,
            self.scroll_offset,
        )
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
        normalize_scroll(&mut state, true);
        state.generation = state.generation.wrapping_add(1);
    }

    pub fn update_view(&self, mut view: NativeOverlay) {
        if !matches!(
            view.kind.as_str(),
            "" | "menu" | "settings" | "stats" | "exit"
        ) {
            view = NativeOverlay::default();
        }
        // Statistics and HUD-only models are deliberately passive. Only the
        // menu, its nested settings page, and exit dialog may own modal input.
        view.input_blocking =
            matches!(view.kind.as_str(), "menu" | "settings" | "exit") && view.input_blocking;
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
            state.scroll_offset = 0.0;
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
        normalize_scroll(&mut state, true);
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
            normalize_scroll(&mut state, true);
            state.generation = state.generation.wrapping_add(1);
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
            normalize_scroll(&mut state, true);
            state.generation = state.generation.wrapping_add(1);
        }
        changed
    }

    /// Scroll by native wheel units (120 per notch). Menu scrolling never
    /// enters the gameplay queue, even when there is no further room to scroll.
    pub fn scroll_wheel(&self, delta: i16) -> bool {
        if !self.presentation_available() || delta == 0 {
            return false;
        }
        let mut state = self
            .state
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        if !matches!(state.view.kind.as_str(), "menu" | "settings") {
            return false;
        }
        let layout = state.layout();
        if layout.max_scroll <= 0.0 {
            return false;
        }
        let next = (state.scroll_offset - f32::from(delta) / 120.0 * 72.0 * layout.scale)
            .clamp(0.0, layout.max_scroll);
        let changed = (next - state.scroll_offset).abs() > f32::EPSILON;
        if changed {
            state.scroll_offset = next;
            state.hovered = None;
            state.pressed = None;
            state.pressed_action = None;
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
        match state.view.kind.as_str() {
            "settings" => Some("stream-menu-back".to_owned()),
            "" => None,
            _ => Some("dismiss-overlay".to_owned()),
        }
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
            (placement_hit(&state.view, &layout, placement, x, y) && focusable(item))
                .then_some(placement.index)
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
            (placement_hit(&state.view, &layout, placement, x, y) && focusable(item))
                .then_some(placement.index)
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

fn placement_hit(
    view: &NativeOverlay,
    layout: &NativeOverlayLayout,
    placement: &NativeOverlayPlacement,
    x: f32,
    y: f32,
) -> bool {
    if !placement.rect.contains(x, y) {
        return false;
    }
    if matches!(view.kind.as_str(), "menu" | "settings")
        && view
            .items
            .get(placement.index)
            .is_some_and(|item| item.role != "appbar")
    {
        return layout.content.is_some_and(|content| content.contains(x, y));
    }
    true
}

fn action_at(view: &NativeOverlay, layout: &NativeOverlayLayout, x: f32, y: f32) -> Option<String> {
    for placement in &layout.items {
        if placement_hit(view, layout, placement, x, y) {
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
    // The reference GFN CEF sidebar is full-height and ignores outside clicks.
    // Keep that behavior for the menu and nested settings; only the exit
    // confirmation retains OpenNOW's click-outside dismissal.
    if view.input_blocking
        && view.kind == "exit"
        && layout.panel.is_some_and(|panel| !panel.contains(x, y))
    {
        return Some("dismiss-overlay".to_owned());
    }
    None
}

fn normalize_scroll(state: &mut NativeOverlaySnapshot, reveal_focus: bool) {
    state.scroll_offset = state
        .scroll_offset
        .clamp(0.0, state.layout().max_scroll.max(0.0));
    if !reveal_focus || !matches!(state.view.kind.as_str(), "menu" | "settings") {
        return;
    }
    let Some(focused) = state.focused else {
        return;
    };
    if state
        .view
        .items
        .get(focused)
        .is_some_and(|item| item.role == "appbar")
    {
        return;
    }
    let layout = state.layout();
    let Some(content) = layout.content else {
        return;
    };
    let Some(rect) = layout
        .items
        .iter()
        .find(|placement| placement.index == focused)
        .map(|placement| placement.rect)
    else {
        return;
    };
    if rect.y < content.y {
        state.scroll_offset = (state.scroll_offset - (content.y - rect.y)).max(0.0);
    } else if rect.y + rect.height > content.y + content.height {
        state.scroll_offset += rect.y + rect.height - content.y - content.height;
    }
    state.scroll_offset = state
        .scroll_offset
        .clamp(0.0, state.layout().max_scroll.max(0.0));
}

pub fn layout_native_overlay(
    view: &NativeOverlay,
    width: u32,
    height: u32,
    dpi_scale: f32,
) -> NativeOverlayLayout {
    layout_native_overlay_at(view, width, height, dpi_scale, 0.0)
}

fn layout_native_overlay_at(
    view: &NativeOverlay,
    width: u32,
    height: u32,
    dpi_scale: f32,
    scroll_offset: f32,
) -> NativeOverlayLayout {
    let width = width.max(2) as f32;
    let height = height.max(2) as f32;
    let scale = finite_clamp(dpi_scale, 0.75, 3.0, 1.0) * finite_clamp(view.scale, 0.85, 1.5, 1.0);
    let mut layout = NativeOverlayLayout {
        scale,
        ..NativeOverlayLayout::default()
    };
    match view.kind.as_str() {
        "menu" | "settings" => layout_menu(view, width, height, scroll_offset, &mut layout),
        "stats" => layout_stats(view, width, height, &mut layout),
        "exit" => layout_exit(view, width, height, &mut layout),
        _ => {}
    }
    layout_hud(view, width, scale, &mut layout);
    layout
}

fn layout_menu(
    view: &NativeOverlay,
    width: f32,
    height: f32,
    scroll_offset: f32,
    layout: &mut NativeOverlayLayout,
) {
    let s = layout.scale;
    // Match the original GFN IGO shell instead of inventing a dashboard:
    // full-height 512 px sidebar, 56 px app bar, and no full-screen scrim.
    let panel = NativeOverlayRect {
        x: 0.0,
        y: 0.0,
        width: (512.0 * s).min(width),
        height,
    };
    layout.panel = Some(panel);
    layout.scrim = false;
    layout.compact = false;
    layout.content = Some(NativeOverlayRect {
        x: panel.x,
        y: panel.y + 56.0 * s,
        width: panel.width,
        height: (panel.height - 56.0 * s).max(0.0),
    });

    let appbar_count = view
        .items
        .iter()
        .filter(|item| item.role == "appbar")
        .count();
    let mut appbar_order = 0_usize;
    let mut rows = Vec::new();
    let mut content_height = 16.0 * s; // Original host bottom padding.
    for (index, item) in view.items.iter().enumerate() {
        if item.role == "appbar" {
            let from_end = appbar_count - 1 - appbar_order;
            appbar_order += 1;
            layout.items.push(NativeOverlayPlacement {
                index,
                rect: NativeOverlayRect {
                    x: panel.x + panel.width - 52.0 * s - from_end as f32 * 60.0 * s,
                    y: panel.y + 10.0 * s,
                    width: 36.0 * s,
                    height: 36.0 * s,
                },
            });
            continue;
        }
        let height = match item.role.as_str() {
            "divider" => 33.0,
            "gap" => 16.0,
            "setting" => 128.0,
            _ if !item.detail.trim().is_empty() || !item.value.trim().is_empty() => 72.0,
            _ => 48.0,
        } * s;
        rows.push((index, height));
        content_height += height;
    }

    let viewport_height = layout.content.map_or(0.0, |content| content.height);
    layout.max_scroll = (content_height - viewport_height).max(0.0);
    layout.scroll_offset = if scroll_offset.is_finite() {
        scroll_offset.clamp(0.0, layout.max_scroll)
    } else {
        0.0
    };
    let mut y = panel.y + 56.0 * s - layout.scroll_offset;
    for (index, item_height) in rows {
        layout.items.push(NativeOverlayPlacement {
            index,
            rect: NativeOverlayRect {
                x: panel.x,
                y,
                width: panel.width,
                height: item_height,
            },
        });
        y += item_height;
    }

    // Action feedback is a transient toast over the game, not a permanent
    // dashboard footer that changes the original sidebar's row geometry.
    if !view.footer.trim().is_empty() {
        let margin = 16.0 * s;
        let toast_width = (420.0 * s).min((width - 2.0 * margin).max(120.0 * s));
        layout.footer = Some(NativeOverlayRect {
            x: (width - margin - toast_width).max(margin),
            y: (height - margin - 48.0 * s).max(margin),
            width: toast_width,
            height: 48.0 * s,
        });
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
        assert_eq!(shared.pointer_up(1800.0, 800.0), None);
        assert_eq!(shared.snapshot().view.kind, "menu");
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
    fn original_sized_menu_scrolls_without_losing_actions() {
        let shared = NativeOverlayShared::new();
        shared.set_viewport(960, 540, 1.0);
        let mut view = menu();
        for item in &mut view.items {
            item.detail = "Ctrl+X - Toggle on/off".to_owned();
        }
        view.items.splice(
            0..0,
            [
                NativeOverlayItem {
                    id: "capture-start".to_owned(),
                    role: "divider".to_owned(),
                    enabled: false,
                    ..NativeOverlayItem::default()
                },
                item("gallery", "open-capture-folder", "chevron"),
                item("record", "toggle-recording", "record"),
                NativeOverlayItem {
                    id: "capture-gap".to_owned(),
                    role: "gap".to_owned(),
                    enabled: false,
                    ..NativeOverlayItem::default()
                },
            ],
        );
        view.items
            .push(item("settings", "open-stream-settings", "appbar"));
        view.items.push(item("close", "dismiss-overlay", "appbar"));
        shared.update_view(view.clone());
        let initial = shared.snapshot();
        let layout = initial.layout();
        let panel = layout.panel.expect("full-height sidebar");
        assert_eq!(panel.x, 0.0);
        assert_eq!(panel.y, 0.0);
        assert_eq!(panel.width, 512.0);
        assert_eq!(panel.height, 540.0);
        assert!(!layout.scrim);
        assert!(!layout.compact);
        assert!(layout.summary.is_none());
        assert_eq!(layout.content.expect("content viewport").y, 56.0);
        assert_eq!(layout.items.len(), view.items.len());
        assert!(layout.max_scroll > 0.0);
        for _ in 0..32 {
            shared.scroll_wheel(-120);
        }
        let scrolled = shared.snapshot();
        let layout = scrolled.layout();
        assert_eq!(layout.scroll_offset, layout.max_scroll);
        let end = layout
            .items
            .iter()
            .find(|placement| view.items[placement.index].id == "end")
            .expect("end action placement")
            .rect;
        let content = layout.content.expect("content viewport");
        assert!(end.y >= content.y && end.y + end.height <= content.y + content.height);
        let x = end.x + end.width / 2.0;
        let y = end.y + end.height / 2.0;
        assert!(shared.pointer_down(x, y));
        assert_eq!(shared.pointer_up(x, y), Some("stop-stream".to_owned()));
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
    fn reference_menu_keeps_appbar_rows_and_toast_geometry() {
        let mut view = menu();
        view.footer = "Screenshot saved".to_owned();
        view.summary = vec![
            item("fps", "", "metric"),
            item("output", "", "metric"),
            item("bitrate", "", "metric"),
        ];
        view.items
            .push(item("settings", "open-stream-settings", "appbar"));
        view.items.push(item("close", "dismiss-overlay", "appbar"));
        for (width, height) in [(1600, 900), (1280, 720), (960, 540)] {
            let layout = layout_native_overlay(&view, width, height, 1.0);
            let panel = layout.panel.expect("menu panel");
            assert_eq!(panel.x, 0.0);
            assert_eq!(panel.y, 0.0);
            assert_eq!(panel.width, 512.0);
            assert_eq!(panel.height, height as f32);
            assert!(!layout.scrim, "GFN must not add a full-screen scrim");
            assert!(layout.summary.is_none(), "dashboard summary returned");
            assert!(layout.footer.is_some(), "action toast missing");
            assert_eq!(layout.items.len(), view.items.len());
            let appbar = layout
                .items
                .iter()
                .filter(|placement| view.items[placement.index].role == "appbar")
                .collect::<Vec<_>>();
            assert_eq!(appbar.len(), 2);
            assert!(appbar.iter().all(|placement| {
                placement.rect.y == 10.0
                    && placement.rect.width == 36.0
                    && placement.rect.height == 36.0
            }));
        }
    }

    #[test]
    fn nested_settings_back_does_not_close_the_stream_menu() {
        let shared = NativeOverlayShared::new();
        shared.update_view(NativeOverlay {
            kind: "settings".to_owned(),
            input_blocking: true,
            items: vec![
                item("clipboard", "toggle-clipboard-paste", "setting"),
                item("back", "stream-menu-back", "appbar"),
                item("close", "dismiss-overlay", "appbar"),
            ],
            ..NativeOverlay::default()
        });
        assert_eq!(shared.cancel(), Some("stream-menu-back".to_owned()));
        assert!(shared.pointer_down(900.0, 600.0));
        assert_eq!(shared.pointer_up(900.0, 600.0), None);
        assert_eq!(shared.snapshot().view.kind, "settings");
    }
}
