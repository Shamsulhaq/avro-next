import Foundation

/// The composition's candidate list and which one is chosen.
///
/// This is the single source of truth for the selection. The system candidate
/// window is only a view of it: its own highlight callbacks are not trusted,
/// because it resets its highlight to the first row when it reloads, which used
/// to overwrite a learned default (and then save that wrong choice).
struct CandidateState: Equatable {
    private(set) var items: [String] = []
    private(set) var selected = 0

    var isEmpty: Bool { items.isEmpty }
    var current: String? { items.indices.contains(selected) ? items[selected] : nil }

    /// Replaces the list with a new suggestion from the engine, selecting the
    /// engine's preferred (possibly learned) index.
    mutating func load(_ newItems: [String], preferred: Int) {
        items = newItems
        selected = newItems.isEmpty ? 0 : min(max(preferred, 0), newItems.count - 1)
    }

    /// Moves the selection by `delta`, clamped to the list. Returns true if it moved.
    @discardableResult
    mutating func move(by delta: Int) -> Bool {
        guard !items.isEmpty else { return false }
        let next = min(max(selected + delta, 0), items.count - 1)
        guard next != selected else { return false }
        selected = next
        return true
    }

    /// Selects the candidate with this exact text (a mouse click). Returns true if found.
    @discardableResult
    mutating func select(text: String) -> Bool {
        guard let i = items.firstIndex(of: text) else { return false }
        selected = i
        return true
    }

    /// Selects the candidate at `index` (a mouse click). Returns true if valid.
    @discardableResult
    mutating func select(index: Int) -> Bool {
        guard items.indices.contains(index) else { return false }
        selected = index
        return true
    }

    mutating func clear() {
        items = []
        selected = 0
    }
}
