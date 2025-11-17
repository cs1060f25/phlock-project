# Waveform Pull-to-Refresh Animation Implementation

**Implementation Date:** November 2025
**Status:** Complete
**Affected Tabs:** Feed, Shares (Inbox), Phlocks

## Overview

Replaced the native iOS circular spinner with a custom animated audio waveform during pull-to-refresh operations across all main tabs. The animation provides a music-inspired visual experience that aligns with Phlock's brand identity.

## User Experience

### Pull-to-Refresh Gesture
1. User pulls down on Feed, Shares, or Phlocks view
2. Waveform bars appear progressively from left to right as the user pulls
3. Bars begin animating with a wave effect once pull progress reaches ~10%
4. Upon release, the waveform plays for ~1.3 seconds while content refreshes
5. Content is pushed down by a spacer to prevent the waveform from covering text
6. Animation fades out after refresh completes

### Tab Re-Selection Refresh
1. User taps on the Feed, Shares, or Phlocks tab button (when already on that tab)
2. First tap: Scrolls to top
3. Second tap: Triggers refresh with animated pull-down effect
4. Waveform animates exactly as if the user manually pulled down
5. Content moves down to accommodate the animation

## Technical Architecture

### Core Components

#### 1. WaveformLoadingView.swift
**Location:** `apps/ios/phlock/phlock/Views/Components/WaveformLoadingView.swift`

Main component containing the waveform animation logic.

**Structure:**
- `WaveformLoadingView`: Container view managing 5 bars
- `WaveformBar`: Individual animated bar component

**Key Features:**
- **Progressive Reveal:** Each bar appears at a different pull progress threshold
  - Bar 0: 0% (appears immediately)
  - Bar 1: 20% progress
  - Bar 2: 40% progress
  - Bar 3: 60% progress
  - Bar 4: 80% progress
- **Individual Opacity:** Each bar fades in over a 15% progress range for smooth transitions
- **Wave Animation:** Staggered 0.1s delay between bars creates wave effect
- **Continuous Animation:** Each bar oscillates between 8pt and 30pt height at 0.5s intervals

**Parameters:**
- `barCount`: Number of bars (default: 5)
- `color`: Bar color (adaptive: white in dark mode, black in light mode)
- `progress`: CGFloat 0.0-1.0 representing pull distance
- `isRefreshing`: Boolean indicating active refresh state

#### 2. CustomRefreshView.swift
**Location:** `apps/ios/phlock/phlock/Views/Components/CustomRefreshView.swift`

Bridges UIKit's scroll view with SwiftUI to track pull progress.

**Components:**
- `PullToRefreshHelper`: UIViewRepresentable that monitors scroll offset
- `pullToRefreshWithWaveform`: View extension that adds waveform to any scrollable view

**How It Works:**
1. Invisible UIView is embedded in the SwiftUI view hierarchy
2. `updateUIView` walks up the view hierarchy to find the parent UIScrollView
3. Monitors `contentOffset.y` to detect pull-down gesture
4. Calculates progress as `(-offsetY) / 80` (80pt = full pull)
5. Updates `pullProgress` binding on main thread for smooth animation
6. Overlays WaveformLoadingView at the top when progress > 0

**Key Implementation Details:**
- No throttling on progress updates for smoothest animation
- Scroll view detection walks entire view hierarchy to handle complex layouts
- Uses native `.refreshable` modifier for gesture handling
- Progress resets to 0 when pull is released or refresh completes

#### 3. View+HideRefreshControl.swift
**Location:** `apps/ios/phlock/phlock/Views/Components/View+HideRefreshControl.swift`

Extension to hide the native iOS refresh control spinner.

```swift
extension View {
    func hideRefreshControl() -> some View {
        self
    }
}
```

Combined with global appearance settings in `phlockApp.swift` to hide native spinner:

```swift
init() {
    UIRefreshControl.appearance().tintColor = .clear
    UIRefreshControl.appearance().backgroundColor = .clear
}
```

### Modified Views

#### FeedView.swift
**State Variables:**
- `@State private var isRefreshing = false`
- `@State private var pullProgress: CGFloat = 0`

**Changes:**
1. Added waveform to loading state
2. Added 50pt spacer when `isRefreshing || pullProgress > 0`
3. Applied `.pullToRefreshWithWaveform()` modifier
4. Added `animatePullDown()` function for tab refresh
5. `onChange(of: refreshTrigger)` handler animates pull gesture

#### InboxView.swift
**State Variables:**
- `@State private var isRefreshing = false`
- `@State private var pullProgress: CGFloat = 0`

**Changes:**
- Same pattern as FeedView
- 50pt spacer for content push-down
- Waveform integration with `.pullToRefreshWithWaveform()`
- Tab refresh animation via `animatePullDown()`

#### MyPhlocksView.swift
**State Variables:**
- `@State private var isRefreshing = false`
- `@State private var pullProgress: CGFloat = 0`

**Changes:**
- Applied to `PhlockGalleryView` subcomponent
- 40pt spacer (slightly smaller due to layout)
- Same waveform integration pattern
- Tab refresh support

### Navigation and Tab Management

#### MainView.swift
**New State Variables:**
- `@State private var refreshPhlocksTrigger = 0`
- `@State private var scrollPhlocksToTopTrigger = 0`

Passed to `CustomTabBarController` to enable tab re-selection refresh.

#### CustomTabBarController.swift
**Added Handler:**
```swift
coordinator.onPhlocksTabReselected = { tapCount in
    DispatchQueue.main.async {
        if self.phlocksNavigationPath.count > 0 {
            self.phlocksNavigationPath = NavigationPath()
        } else {
            switch tapCount {
            case 1:
                self.scrollPhlocksToTopTrigger += 1
            default:
                self.refreshPhlocksTrigger += 1
            }
        }
    }
}
```

Similar handlers exist for Feed and Shares tabs.

## Animation Timing

| Event | Duration | Purpose |
|-------|----------|---------|
| Pull-down animation (tab refresh) | 0.4s | Simulates pull gesture |
| Per-bar animation cycle | 0.5s | Height oscillation (8pt ↔ 30pt) |
| Bar stagger delay | 0.1s | Creates wave effect |
| Minimum refresh display | 1.3s | Ensures full animation plays |
| Progress fade-out | 0.3s | Smooth return to idle state |

## Color Scheme

- **Dark Mode:** White bars (`Color.white`)
- **Light Mode:** Black bars (`Color.black`)
- **Implementation:** Adaptive via `@Environment(\.colorScheme)`

## Files Modified/Created

### Created Files
1. `apps/ios/phlock/phlock/Views/Components/WaveformLoadingView.swift`
2. `apps/ios/phlock/phlock/Views/Components/CustomRefreshView.swift`
3. `apps/ios/phlock/phlock/Views/Components/View+HideRefreshControl.swift`

### Modified Files
1. `apps/ios/phlock/phlock/Views/Main/FeedView.swift`
2. `apps/ios/phlock/phlock/Views/Main/InboxView.swift`
3. `apps/ios/phlock/phlock/Views/Main/MyPhlocksView.swift`
4. `apps/ios/phlock/phlock/Views/Main/MainView.swift`
5. `apps/ios/phlock/phlock/CustomTabBarController.swift`
6. `apps/ios/phlock/phlock/phlockApp.swift`

## Implementation Challenges & Solutions

### Challenge 1: Native Spinner Still Visible
**Problem:** iOS native refresh control spinner appeared alongside custom waveform.

**Solution:**
- Added global `UIRefreshControl.appearance()` settings in `phlockApp.swift`
- Set `tintColor` and `backgroundColor` to `.clear`
- Created passthrough `hideRefreshControl()` extension for clarity

### Challenge 2: Static Animation
**Problem:** Waveform appeared as static image, not fluid animation.

**Solution:**
- Refactored to individual `WaveformBar` components
- Each bar has its own `@State` animation phase
- Used `.repeatForever(autoreverses: true)` for continuous oscillation
- Staggered animation start with 0.1s delays

### Challenge 3: Pull-to-Refresh Gesture Broke
**Problem:** Custom implementation interfered with native gesture detection.

**Solution:**
- Reverted to native `.refreshable` modifier for gesture handling
- Used overlay approach for waveform instead of replacing refresh control
- Let iOS handle all touch events and scroll physics

### Challenge 4: All Bars Appearing at Once
**Problem:** Entire waveform appeared instantly instead of progressive left-to-right reveal.

**Root Cause:** Conflicting opacity systems:
- Individual bar opacity (correct, threshold-based)
- Overall view opacity (incorrect, applied on top)

**Solution:**
- Removed overall `.opacity()` modifier from `CustomRefreshView.swift`
- Each bar now controls its own opacity independently
- Progressive reveal works via `barOpacity(for index:)` calculation

### Challenge 5: Tab Refresh Not Mimicking Pull
**Problem:** Tab re-selection showed brief flash instead of smooth pull animation.

**Solution:**
- Created `animatePullDown()` function:
  ```swift
  private func animatePullDown() async {
      withAnimation(.easeOut(duration: 0.4)) {
          pullProgress = 1.0
      }
      try? await Task.sleep(nanoseconds: 400_000_000)
  }
  ```
- Called before triggering refresh in `onChange(of: refreshTrigger)`
- Progress animates 0→1 over 0.4s, mimicking manual pull

### Challenge 6: Waveform Covering Text
**Problem:** Animation overlay blocked content (especially on Phlocks page).

**Solution:**
- Added conditional spacers to all List views:
  ```swift
  if isRefreshing || pullProgress > 0 {
      Color.clear
          .frame(height: 50)
          .listRowSeparator(.hidden)
          .listRowInsets(EdgeInsets())
  }
  ```
- Spacer pushes content down when animation is visible
- Uses `Color.clear` to avoid visual artifacts

### Challenge 7: Smooth Pull Tracking
**Problem:** Progress updates were throttled, causing choppy bar appearance.

**Solution:**
- Improved scroll view detection in `PullToRefreshHelper`
- Walks entire view hierarchy to reliably find `UIScrollView`
- Removed all throttling from progress updates
- Updates on every `contentOffset.y` change for smooth tracking

## How Pull Progress Calculation Works

```swift
let offsetY = scrollView.contentOffset.y

if offsetY < 0 && !isRefreshing {
    // Pull down creates negative offset
    let progress = min(1.0, max(0, (-offsetY) / 80))
    // -80pt offset = 100% progress (full pull)
    // -40pt offset = 50% progress
    // -8pt offset = 10% progress (bars start animating)
}
```

**Visual Breakdown:**
- 0pt offset → 0% progress (no pull)
- -20pt offset → 25% progress (bars 0-1 visible)
- -40pt offset → 50% progress (bars 0-2 visible)
- -60pt offset → 75% progress (bars 0-3 visible)
- -80pt+ offset → 100% progress (all bars visible, full animation)

## Integration Pattern for New Views

To add waveform refresh to a new view:

1. **Add State Variables:**
   ```swift
   @State private var isRefreshing = false
   @State private var pullProgress: CGFloat = 0
   ```

2. **Add Spacer to ScrollView/List:**
   ```swift
   if isRefreshing || pullProgress > 0 {
       Color.clear
           .frame(height: 50)
           .listRowSeparator(.hidden)
           .listRowInsets(EdgeInsets())
   }
   ```

3. **Apply Waveform Modifier:**
   ```swift
   .pullToRefreshWithWaveform(
       isRefreshing: $isRefreshing,
       pullProgress: $pullProgress,
       colorScheme: colorScheme
   ) {
       isRefreshing = true
       await loadData()
       try? await Task.sleep(nanoseconds: 1_300_000_000)
       isRefreshing = false
   }
   ```

4. **Add Tab Refresh Support (Optional):**
   ```swift
   .onChange(of: refreshTrigger) { _, _ in
       Task {
           await animatePullDown()
           isRefreshing = true
           await loadData()
           try? await Task.sleep(nanoseconds: 1_300_000_000)
           isRefreshing = false
           withAnimation(.easeOut(duration: 0.3)) {
               pullProgress = 0
           }
       }
   }

   private func animatePullDown() async {
       withAnimation(.easeOut(duration: 0.4)) {
           pullProgress = 1.0
       }
       try? await Task.sleep(nanoseconds: 400_000_000)
   }
   ```

## Performance Considerations

- **Main Thread Updates:** All `pullProgress` updates happen on main thread via `DispatchQueue.main.async` to ensure smooth UI
- **Animation State:** Each bar maintains its own animation state to avoid recalculation
- **View Hierarchy Walking:** Scroll view detection happens in `updateUIView`, which is called frequently—kept lightweight
- **No Re-renders:** WaveformLoadingView only re-renders when `progress` or `isRefreshing` changes

## Testing Notes

- **Test on both light and dark mode** to verify color adaptation
- **Test pull gesture** at different speeds and distances
- **Test tab re-selection** (single tap for scroll, double tap for refresh)
- **Test deep navigation** (tab refresh should pop to root first)
- **Verify spacer behavior** on different screen sizes
- **Check animation smoothness** on physical devices (simulators may lag)

## Future Enhancements

Potential improvements for future iterations:

1. **Haptic Feedback:** Add subtle haptics when bars appear during pull
2. **Sound Design:** Optional audio waveform visualization based on actual music data
3. **Customizable Bar Count:** Allow users to choose 3-7 bars in settings
4. **Color Themes:** Let users select custom waveform colors
5. **Pull Distance Customization:** Make the 80pt threshold configurable
6. **Performance Metrics:** Add analytics to track pull-to-refresh usage

## Maintenance Notes

- Waveform animation is fully self-contained in `WaveformLoadingView.swift`
- Changing bar count, timing, or heights requires only edits to that file
- Pull tracking logic is isolated in `CustomRefreshView.swift`
- Each view independently manages its own refresh state
- Global appearance settings in `phlockApp.swift` must remain for hiding native spinner

## Dependencies

- **SwiftUI:** Core framework
- **UIKit Interop:** `UIViewRepresentable` for scroll tracking
- **Async/Await:** Used for animation timing and refresh operations
- **No External Libraries:** Fully native implementation

## Known Limitations

1. **Preview URLs:** Pull-to-refresh reloads content, but some tracks may still lack preview URLs (unrelated to animation)
2. **Simulator Performance:** Animation may appear choppy on slow simulators—test on device for accurate experience
3. **iOS Version:** Requires iOS 15+ due to `.refreshable` modifier and async/await
4. **Scroll View Detection:** Relies on view hierarchy walking—may need adjustment if view structure changes significantly

## References

- Spotify API Docs: https://developer.spotify.com/documentation/web-api
- SwiftUI Animations: https://developer.apple.com/documentation/swiftui/animation
- UIScrollView: https://developer.apple.com/documentation/uikit/uiscrollview
- UIViewRepresentable: https://developer.apple.com/documentation/swiftui/uiviewrepresentable

---

**Last Updated:** November 8, 2025
**Implemented By:** AI Assistant (Claude)
**Project:** Phlock - Social Music Discovery Platform
**Phase:** Phase 1 - Social MVP
