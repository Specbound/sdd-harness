---
name: hig
description: Apple Human Interface Guidelines — design foundations, components, interaction patterns, platform differences (iOS/iPadOS/macOS/tvOS/watchOS/visionOS), input methods, and Apple tech integrations. Use when choosing/designing a UI component, planning a UX flow, or adapting UI across Apple platforms.
---

# Apple Human Interface Guidelines

One set of guidelines, six platforms. Components, patterns, and inputs differ mainly by each platform's primary input model (touch / pointer+keyboard / remote+focus / Digital Crown / eyes+gesture) and viewing distance — adapt *intent*, never port a design 1:1 between platforms.

## Project context (check first)
Before asking the user anything, check for `.claude/apple-design-context.md`. If present, use it and only ask about gaps. If absent, auto-discover from: `README.md` (product/platforms), `Package.swift`/`.xcodeproj` (supported platforms, min OS), `Info.plist` (capabilities, orientations), existing imports (SwiftUI vs UIKit/AppKit, HealthKit/ARKit/etc.), `Assets.xcassets` (color assets, dark mode variants). Present findings for confirmation, then ask only what's still missing: target platforms, UI framework, design-system base (system defaults vs custom), accessibility target level, 1-3 personas/use contexts. Write confirmed answers back to `.claude/apple-design-context.md` (Product / Platforms table / Technology / Design System / Accessibility / Users) so later questions in the same project are skipped.

## Cross-cutting principles (apply regardless of domain)
1. **Accessibility is not a phase.** Every interactive element needs a VoiceOver label/trait. Support Dynamic Type, Reduce Motion (crossfade alternative to every animation), Increase Contrast, Switch Control from the start.
2. **System components first.** They carry built-in accessibility and platform adaptation for free; only go custom when a system component genuinely can't express the need.
3. **Semantic over literal.** Semantic colors (`label`, `secondaryLabel`, `systemBackground`) adapt to light/dark/contrast automatically; SF Symbols match system weight/optical sizing — prefer both over hard-coded values/custom icons.
4. **Minimize modality.** Reach for a modal only when it's critical for attention, completion, or save-before-leaving. Prefer inline feedback or **undo over a confirmation dialog** for destructive actions.
5. **Consistent feedback.** Every action (tap, drag, voice command, controller input) gets a visible/audible/haptic response.
6. **Standard gestures/shortcuts stay standard.** Don't override system gestures (edge swipes, Cmd+C/V/Z); custom gestures need discoverable hints.
7. **Privacy is minimal + just-in-time.** Request a permission only when the user is about to benefit from it, with a specific usage description — never bundle every permission request at launch.
8. **Launch and onboard fast.** No splash/logo screens; restore previous state. Onboarding ≤3 screens, skippable, teach via progressive disclosure instead of upfront tutorials.

## Platforms
| Platform | Primary input | Navigation default | Notes |
|---|---|---|---|
| iOS | Touch, one-handed | Tab bar + push/pop stack | Compact width; favor easy one-handed thumb reach |
| iPadOS | Touch + pointer + keyboard | Sidebar + `NavigationSplitView`, adapts to tabs | Must handle Split View / Slide Over / Stage Manager at every size class |
| macOS | Pointer + keyboard | Menu bar (every command must be reachable here) + toolbar + sidebar | Dense layouts acceptable; resizable windows, extensive shortcuts |
| tvOS | Siri Remote + focus engine | Focus-based, large lean-back layouts | Viewed from a distance; parallax, top shelf, no fine pointer control |
| watchOS | Digital Crown + touch + haptics | Glanceable, brief interactions | Complications for timely data; Move/Exercise/Stand ring color convention is fixed (red/green/blue) |
| visionOS | Eyes (look) + pinch + hands | Windows / volumes / spaces, ornaments for toolbars | Generous hit targets (eye tracking < touch precision); respect ergonomic depth/comfort zones |
| Games | Controller-first, own model | Free, but still platform-conformant for system surfaces | Always offer touch/keyboard fallback for MFi controller actions |

## Component quick-pick
| Family | Component | Use when |
|---|---|---|
| Content | Charts (Swift Charts) | Visualizing quantitative data; needs audio-graph accessibility |
| Content | Collection view | Grid/list of items; compositional layout for complex arrangements, cell reuse for scale |
| Content | Image view / well | Single image display (view) vs drag-and-drop image picking, macOS (well) |
| Content | Web view (WKWebView) | Inline web content; `SFSafariViewController` for external browsing instead |
| Content | Activity view | System share sheet / share-to-other-apps |
| Content | Lockup | Image+text card, mainly tvOS shelves |
| Controls | Toggle | Binary on/off; immediate effect in Settings-style screens |
| Controls | Segmented control | 2-5 mutually exclusive, equal-weight, short-label options |
| Controls | Slider | Continuous value, precision not critical; label the endpoints |
| Controls | Stepper | Small precise increment/decrement with bounded min/max |
| Controls | Picker | Long option list (dates, times, structured data) |
| Controls | Text field / text view | Single-line vs multi-line input; set keyboard type to match (email/URL/number) |
| Controls | Combo box / token field | macOS only — type-or-select, and discrete tag/chip values (recipients, tags) |
| Controls | Gauge / rating indicator | Display-only value-in-range vs star rating; use interactive variants for input |
| Dialogs | Alert | Critical/destructive-confirmation/must-acknowledge only; specific verb button labels, never bare "OK" |
| Dialogs | Sheet | Focused task that preserves context (create/edit/multi-step form) |
| Dialogs | Popover | Non-modal on iPad/Mac, anchored to trigger, dismiss on outside tap |
| Dialogs | Action sheet | Choosing among actions, one possibly destructive; iPhone slides up, iPad renders as popover |
| Dialogs | Digit entry view | PIN-style input; auto-advance + autofill support |
| Layout | Tab bar / tab view | 3-5 flat peer sections (iPhone bottom bar; `.sidebarAdaptable` → sidebar on iPad 18+) |
| Layout | Sidebar + `NavigationSplitView` | Deep hierarchical content, two/three column adaptive |
| Layout | Column view | Finder-style browsing through nested hierarchy (macOS) |
| Layout | Outline view | Expandable tree with disclosure triangles |
| Layout | Scroll view | Overflowing content; paging for discrete units, respect safe areas |
| Layout | List / table | Plain/grouped/inset-grouped; swipe actions, section headers |
| Layout | Window / panel | macOS/visionOS doc windows + inspector/utility panels |
| Layout | Ornament | visionOS toolbar attached to a window without occluding content |
| Menus | Menu bar | macOS primary command surface — every command must be reachable here |
| Menus | Toolbar | Most-frequent actions; rare actions go in a menu instead |
| Menus | Context menu | Secondary actions via right-click/long-press — never the *only* place a command lives |
| Menus | Pop-up button | Exactly-one-of-N mutually exclusive choice |
| Menus | Pull-down button | Action list with no current selection |
| Menus | Disclosure control | Progressive show/hide of extra content |
| Search/Nav | Search field | Top of list/toolbar, instant-as-you-type results, scopes for large result sets |
| Search/Nav | Page control | Flat, equally-weighted page sequence only (onboarding, gallery) — not hierarchy |
| Search/Nav | Path control | macOS breadcrumb; click any ancestor segment to jump |
| Status | Progress bar | Determinate — duration/percentage known; feels faster/more trustworthy than a spinner |
| Status | Spinner | Indeterminate — duration unknown (unpredictable network call) |
| Status | Activity rings | watchOS Move/Exercise/Stand only — don't repurpose the metaphor; source data from HealthKit |
| System | Widget | Glanceable subset of content outside the app; deep-link on tap, distinct layout per size |
| System | Live Activity | Clear start/end event (delivery, score, timer); Dynamic Island + Lock Screen, end promptly |
| System | Notification | Only genuinely valuable info; actionable + self-contained, threaded/grouped, never promotional |
| System | Complication | Smallest useful watch-face representation; budget updates |
| System | App Clip | Instant, size-budgeted, single focused task, then offer full install |
| System | App Shortcut | Surface a frequent action to Siri/Spotlight with a natural trigger phrase |

## Inputs
Support every input a platform offers (iPadOS: touch *and* pointer; macOS: pointer *and* keyboard). Standard gesture recognizers handle edge cases and accessibility — don't reimplement tap/swipe/pinch/long-press/drag. Apple Pencil: support pressure/tilt/hover and Scribble in any text field. Keyboard: standard shortcuts (Cmd+C/V/Z) plus a visible custom-shortcut overlay on iPadOS, logical tab order. Game controllers: MFi extended-gamepad profile, remappable, always with a touch/keyboard fallback. Digital Crown is the primary watchOS scroll/value-adjust input, with haptic detents. tvOS/visionOS live or die on the **focus system** — every interactive element focusable, predictable movement, clear focus indicator. visionOS eye-tracking needs generous hit targets and avoids sustained-gaze activation. Motion sensors (gyro/accelerometer/UWB): fine for games/fitness/AR, never for essential tasks — always provide calibration/reset.

## Patterns
Favor **undo over confirm**, **progressive disclosure over all-options-at-once**, **skeleton/progress over blocking spinners**, **contextual just-in-time permission requests over upfront bulk asks**, **inline validation + autofill over modal forms** for simple input, and **in-app settings for frequently-changed items** (don't bury everything in the system Settings app). Drag-and-drop needs spring-loading and clear drop-target feedback. File management should go through the document browser / file providers rather than custom file UI. Haptics (`UIFeedbackGenerator`/Core Haptics) reinforce physical actions; sound is supplemental, never the only feedback channel.

## Foundations
Dynamic Type must scale without breaking layout (use text styles + Auto Layout, not fixed frames). Custom color palettes must hold WCAG contrast in *both* light and dark — start from system semantic colors and only diverge deliberately. Icons should match SF Symbols weight/optical sizing even when custom. Every animation needs a Reduce-Motion-safe alternative (typically a crossfade). Support RTL mirroring and text-expansion-safe layouts for internationalization. UI copy: short, specific verbs on buttons ("Delete", "Save") not "OK", consistent tone, no jargon in error messages.

## Technologies (integration checklist shape)
For any Apple technology integration (Siri, Apple Pay, HealthKit, HomeKit, ARKit, Core ML/generative AI, iCloud, Sign in with Apple, SharePlay, CarPlay, Game Center, NFC/Wallet, Maps, Mac Catalyst): state the required vs optional capabilities, the privacy/permission prompt and its justification copy, the user-facing flow end to end, and how failures/offline degrade gracefully. Payments: standard Apple Pay button styles, never ask for card details when Apple Pay is available. AI features: attribute AI-generated content, let the user edit/regenerate/dismiss. CarPlay: minimize interaction complexity, large targets, only audio/messaging/EV-charging/navigation/parking/food-ordering app types are permitted.

## Output format (apply to any HIG question)
1. Recommendation with rationale (why this component/pattern over the alternatives).
2. Configuration/behavior: state management, dismiss behavior, or content strategy as applicable.
3. Accessibility requirements specific to the recommendation.
4. Platform-specific notes for every platform in scope.

## Questions to ask (when context doc doesn't already answer them)
1. What is this for — content type, action, or navigation need?
2. Which platform(s)?
3. Scale — a handful of items/options, or hundreds+?
4. Does this involve a destructive, financial, or identity-sensitive action?
