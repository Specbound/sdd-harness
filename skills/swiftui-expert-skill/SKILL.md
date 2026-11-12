---
name: swiftui-expert-skill
description: "SwiftUI best practices: @Observable state, modern API swaps, composition, performance, iOS 26 Liquid Glass. Use when writing or reviewing SwiftUI."
source: "https://github.com/AvdLee/SwiftUI-Agent-Skill/tree/main/swiftui-expert-skill"
risk: safe
---

# SwiftUI Expert

Build, review, or improve SwiftUI with correct state management, modern APIs, Swift
concurrency, performant view composition, and iOS 26+ Liquid Glass. Facts and best
practices only — this skill does not enforce an architecture (no MVVM/VIPER mandate),
though it does push business logic out of views so it stays testable.

## When to Use

Building, refactoring, or reviewing SwiftUI views; auditing state management; replacing
deprecated APIs; adopting Liquid Glass.

## Workflow

**Reviewing code** — walk the sections below in order and report violations with the
replacement. **Writing new code** — design data flow first (what is owned vs injected),
then compose views small, then apply the performance rules to hot paths only.
**Adopting Liquid Glass** — only when the user explicitly asks.

Everything below is self-contained; there is no external reference material to load.

## State Management

- [ ] Prefer `@Observable` over `ObservableObject` for all new code
- [ ] Mark `@Observable` classes `@MainActor` unless using default actor isolation
- [ ] Use `@State` (not `@StateObject`) to own an `@Observable` class
- [ ] `@State` and `@StateObject` are always `private`
- [ ] Never declare a passed-in value as `@State`/`@StateObject` — they take an initial value only, later changes are ignored
- [ ] `@Binding` only when the child *modifies* parent state
- [ ] `@Bindable` for an injected `@Observable` that needs bindings
- [ ] `let` for read-only values; `var` + `.onChange()` when the child must react
- [ ] Nested `ObservableObject` does not publish — pass the nested object directly. `@Observable` nests correctly

| Wrapper | Use when |
|---------|----------|
| `@State` | Internal view state (`private`), or an owned `@Observable` |
| `@Binding` | Child modifies parent's state |
| `@Bindable` | Injected `@Observable` needing bindings |
| `let` | Read-only value from parent |
| `var` | Read-only value watched via `.onChange()` |
| `@StateObject` | Legacy: view owns an `ObservableObject` |
| `@ObservedObject` | Legacy: view receives an `ObservableObject` |

## Modern API Replacements

| Deprecated | Modern |
|------------|--------|
| `foregroundColor()` | `foregroundStyle()` |
| `cornerRadius()` | `clipShape(.rect(cornerRadius:))` |
| `tabItem()` | `Tab` API |
| `onTapGesture()` | `Button` (unless you need location/count) |
| `NavigationView` | `NavigationStack` + `navigationDestination(for:)` |
| `onChange(of:) { value in }` | `onChange(of:) { old, new in }` or no-parameter form |
| `fontWeight(.bold)` | `bold()` |
| `GeometryReader` | `containerRelativeFrame()` or `visualEffect()` |
| `showsIndicators: false` | `.scrollIndicators(.hidden)` |
| `String(format: "%.2f", v)` | `Text(v, format: .number.precision(.fractionLength(2)))` |
| `string.contains(search)` | `string.localizedStandardContains(search)` for user input |
| `UIScreen.main.bounds` | relative layout; never size from the screen |

Also: `.sheet(item:)` over `.sheet(isPresented:)` for model-driven content, and sheets
own their actions and call `dismiss()` themselves. `ImageRenderer` to rasterise a view.
`ScrollViewReader` with stable IDs for programmatic scrolling. `.task` for auto-cancelled
async work, `.task(id:)` when it depends on a value. Prefer static member lookup
(`.blue` over `Color.blue`).

## View Composition

- [ ] Prefer modifiers over conditional views for state changes — a conditional swaps view identity and loses state/animation
- [ ] Extract complex views into subviews early
- [ ] Keep `body` simple and pure — no side effects, no object creation, no heavy computation
- [ ] `@ViewBuilder` functions only for small sections; prefer `@ViewBuilder let content: Content` over closure properties
- [ ] Action handlers call methods, they do not inline logic
- [ ] Business logic lives in testable models, not views
- [ ] Relative layout, not hard-coded constants — views must work in any context
- [ ] Buttons with image-only labels still carry a text label for accessibility

## Performance

- [ ] Pass only the values a view needs — never a large "config"/"context" object
- [ ] Eliminate unneeded dependencies to shrink update fan-out
- [ ] Compare before assigning state in hot paths (`onReceive`, `onChange`, scroll handlers)
- [ ] `LazyVStack`/`LazyHStack` for large lists
- [ ] `ForEach` uses stable identity — never `.indices` for dynamic content
- [ ] Constant number of views per `ForEach` element
- [ ] No inline filtering in `ForEach` — prefilter and cache
- [ ] No `AnyView` in list rows
- [ ] Consider POD views for fast diffing, or wrap expensive views in a POD parent
- [ ] Downsample images when you see `UIImage(data:)` (suggest as an optimisation, not a defect)
- [ ] Avoid layout thrash: deep hierarchies, excessive `GeometryReader`; gate frequent geometry updates by a threshold

Debug unexpected redraws with `Self._printChanges()`.

## Liquid Glass (iOS 26+)

Only adopt when the user explicitly asks for it.

- [ ] Gate with `#available(iOS 26, *)` and provide a fallback
- [ ] Wrap multiple glass elements in one `GlassEffectContainer`
- [ ] Apply `.glassEffect()` *after* layout and appearance modifiers
- [ ] `.interactive()` only on tappable/focusable elements
- [ ] `glassEffectID` with `@Namespace` for morphing transitions
- [ ] Shapes and tints consistent across related elements

```swift
// Basic glass effect with fallback
if #available(iOS 26, *) {
    content
        .padding()
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
} else {
    content
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
}

// Grouped glass elements
GlassEffectContainer(spacing: 24) {
    HStack(spacing: 24) {
        GlassButton1()
        GlassButton2()
    }
}

// Glass button
Button("Confirm") { }
    .buttonStyle(.glassProminent)
```
