---
name: avalonia-zafiro-development
description: Mandatory conventions for Avalonia UI apps built on the Zafiro toolkit — functional-reactive MVVM, DynamicData pipelines, layout/theming, wizards, navigation, and DI composition. Use when writing or reviewing Avalonia+Zafiro ViewModels, Views, or XAML.
---

# Avalonia Zafiro Development

Conventions for cross-platform apps built with Avalonia UI + the Zafiro toolkit, prioritizing maintainability, correctness, and a functional-reactive style.

## Core pillars
1. **Functional-Reactive MVVM**: pure MVVM logic using DynamicData and ReactiveUI; ViewModels must never reference Avalonia types.
2. **Safety & predictability**: explicit `Result`/`Maybe` (CSharpFunctionalExtensions) for flow control; exceptions reserved for truly unrecoverable situations and never leaked across architectural boundaries.
3. **Composition over inheritance**; inward dependency flow (abstractions don't depend on implementations); prefer immutability.
4. **Zafiro first**: search for an existing Zafiro helper/abstraction/extension before writing new logic.

## Before writing code
1. Search the codebase for an existing implementation or Zafiro helper.
2. If missing, add a reusable extension method rather than inlining complex logic.
3. Use DynamicData operators instead of plain Rx wherever collections are involved.

## Naming & error handling
- Explicit names over clever ones; no `Async` suffix on method names even when returning `Task`; no `_` prefix on private fields.
- Keep methods small and low-complexity; avoid static state unless explicitly justified.
- Use `Result`/`Maybe` types for flow control; exceptions only for truly exceptional cases.

## Reactive & DynamicData rules
- Prefer DynamicData operators (`Connect`, `Filter`, `Transform`, `Sort`, `Bind`, `DisposeMany`) over plain Rx when working with collections; keep pipelines a single readable chain.
- `DisposeWith` for lifecycle; subscriptions minimal, centralized, side-effects only.
- Never: create ad-hoc `SourceList`/`SourceCache` for local problems, put business logic inside `Subscribe`, or use a `System.Reactive` operator when a DynamicData equivalent exists.
- Filtering nulls: `this.WhenAnyValue(x => x.Prop).WhereNotNull()`.

## ViewModels & commands
- Base on `ReactiveObject`; declare properties with `[Reactive]` (ReactiveUI.SourceGenerators).
- `WhenAnyValue(...).Select(...).ToPropertyEx(this, x => x.Derived)` for derived state.
- Commands: `ReactiveCommand.Create[FromTask]` then `.Enhance(text:, name:)` to get an `IEnhancedCommand` with metadata/progress reporting.
- Pipe command/collection errors with `.HandleErrorsWith(notificationService, "message")` instead of manual `Subscribe`.
- Always own a `CompositeDisposable` and `.DisposeWith(disposables)` every subscription/command.

## Wizards & navigation
- Multi-step flows: `WizardBuilder.StartWith(...).NextUnit()/NextCommand()/WhenValid().Then(...).WithCompletionFinalStep()` → `SlimWizard<T>`; navigate with `await wizard.Navigate(navigator)`. `SlimWizard` handles Back automatically.
- Page/view navigation: `INavigator.Navigate(() => new XViewModel())`.
- UI sections (tabs/sidebar): mark ViewModels with `[Section("Name", icon: "fa-x")]`, auto-register via `services.AddAnnotatedSections(logger)` / `AddSectionsFromAttributes(logger)`, switch with `shellViewModel.SetSection("Name")`.

## Composition & DI
- Map ViewModel→View via `DataTypeViewLocator` registered in `Application.DataTemplates`.
- Centralize registration in a `CompositionRoot` (`AddViewModels()`, `AddUIServices()`); pick scope (Transient/Scoped/Singleton) deliberately.
- Bootstrap with `this.Connect(() => new ShellView(), view => CompositionRoot.CreateMainViewModel(view), () => new MainWindow())` in `OnFrameworkInitializationCompleted`.
- Use `ActivatorUtilities.CreateInstance` to manually instantiate a class while still resolving its DI dependencies.

## Layout & XAML
- Prefer semantic containers over raw `Border`/`Grid`: `HeaderedContainer` (titled section), `EdgePanel` (Start/Content/End slots — label-value or icon-text-action rows), `Card` (grouped info block).
- Flatten nesting: `StackPanel` with `Spacing` for simple linear layouts, `EdgePanel` or a generic component instead of deep `Grid`/`StackPanel` nesting, `UniformGrid` for equal-size cells.
- Icons via the `{Icon fa-name}` markup extension (not manual resource lookups); style consistently with `IconOptions.{Size,Fill,Background,Padding,CornerRadius}` in a `Style` selector.
- Interaction logic goes in `Interaction.Behaviors`, not code-behind or converters. Prefer, in order: a ViewModel property already in display format → `MultiBinding` for simple And/Or → a `Behavior` for stateful/event-driven logic. Reserve `IValueConverter` for purely visual, highly reusable conversions.
- Themes: colors/brushes in a dedicated `Colors.axaml` (via `DynamicResource`), styles grouped by category (`Buttons.axaml`, `Containers.axaml`, ...), aggregated into `Theme.axaml`; never repeat the same literal property values across elements — define a `Classes="Name"` style instead.

## Common patterns
- **RefreshableCollection**: `RefreshableCollection.Create(() => GetDataTask(), model => model.Id).DisposeWith(disposables)` — exposes `.Refresh` command and `.Items` (`ReadOnlyObservableCollection`), updates via `EditDiff` instead of clearing the list.
- **Validating a dynamic collection**: `this.ValidationRule(Source.Connect().FilterOnObservable(x => x.IsValid).IsEmpty(), b => !b, _ => "message").DisposeWith(disposables)`.

## Zafiro shortcuts (check before writing custom Rx)
| Standard pattern | Shortcut |
| --- | --- |
| `Replay(1).RefCount()` | `ReplayLastActive()` |
| `Select(_ => Unit.Default)` | `ToSignal()` |
| `Select(b => !b)` | `Not()` |
| `Where(b => b).ToSignal()` / `Where(b => !b).ToSignal()` | `Trues()` / `Falses()` |
| `Select(x => x is [not] null)` | `Null()` / `NotNull()` |
| `Select(string.IsNullOrWhiteSpace)` | `NullOrWhitespace()` / `NotNullOrEmpty()` |
| `Where(r => r.IsSuccess).Select(r => r.Value)` | `Successes()` |
| `Where(r => r.IsFailure).Select(r => r.Error)` | `Failures()` |
| `Where(m => m.HasValue).Select(m => m.Value)` | `Values()` / `Empties()` |

Check `Zafiro.Reactive.ObservableMixin` and `Zafiro.CSharpFunctionalExtensions.ObservableExtensions` before writing custom Rx logic.

## Reference files (read only the one relevant to the task)
| File | Covers |
| --- | --- |
| `core-technical-skills.md` | Required expertise & architectural principles |
| `naming-standards.md` | Naming, fields, error-handling rules |
| `avalonia-reactive-rules.md` | Avalonia purity rules + DynamicData canonical patterns |
| `zafiro-shortcuts.md` | Full Rx→Zafiro shortcut tables |
| `patterns.md` | `RefreshableCollection`, validation, error pipelines |
| `viewmodels.md` | ViewModel/command detail and examples |
| `wizards.md` | `SlimWizard`/`WizardBuilder` detail |
| `navigation_sections.md` | `INavigator`, `[Section]`, shell switching |
| `composition.md` | `DataTypeViewLocator`, `CompositionRoot`, DI scopes |
| `themes.md` | Theme file organization |
| `containers.md` | `HeaderedContainer`/`EdgePanel`/`Card` detail |
| `icons.md` | `IconExtension`/`IconOptions` detail |
| `behaviors.md` | `Interaction.Behaviors`, avoiding converters |
| `components.md` | Generic component extraction, flattening layouts |
