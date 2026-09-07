# Task 1: Shared Component Library

Create four reusable widgets at `lib/src/core/components/`:

## 1. StatusBadge (`status_badge.dart`)
A small colored chip showing status text.
- Props: `String label`, `Color color` (defaults to blue)
- Returns a `Container` with `borderRadius: BorderRadius.circular(12)` padding `EdgeInsets.symmetric(horizontal: 8, vertical: 4)`, `color` background, white text label.
- Export from `lib/src/core/components/components.dart`

## 2. ProgressBar (`progress_bar.dart`)
A horizontal progress indicator with label.
- Props: `double value` (0.0 to 1.0), `String label` (optional, shows percentage if null)
- Returns a `Column` with a `ClipRRect` containing a `LinearProgressIndicator` and optional text below.
- Clamp `value` to 0.0–1.0 range.
- Export from `lib/src/core/components/components.dart`

## 3. SkeletonLoader (`skeleton_loader.dart`)
A pulsing placeholder for loading states.
- Props: `double? width`, `double height` (default 16), `BorderRadius? borderRadius` (default 8)
- Returns an `AnimatedContainer` with shimmer-like color cycling between two grays (e.g., `Colors.grey[800]` and `Colors.grey[700]`) via an `AnimationController` (repeat, 800ms).
- Export from `lib/src/core/components/components.dart`

## 4. EmptyState (`empty_state.dart`)
A centered placeholder for empty lists.
- Props: `String message` (default "No data available"), `IconData icon` (default `Icons.inbox_outlined`), `VoidCallback? onAction`, `String? actionLabel`
- Returns a `Column` with `Icon`, `Text`, optional `TextButton`.
- Export from `lib/src/core/components/components.dart`

## Testing
Write tests at `test/core/components/`:
- `test/core/components/status_badge_test.dart`: renders label and applies color
- `test/core/components/empty_state_test.dart`: renders message and optional action button

## Commit
`feat(admin): add shared component library (StatusBadge, ProgressBar, SkeletonLoader, EmptyState)`
