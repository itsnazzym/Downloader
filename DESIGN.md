---
version: alpha
name: TapLoad
description: A compact, dark-first desktop and mobile media library. Existing theme presets provide the live semantic colors; this document records the default Midnight palette and the shared spacing and type scale.
colors:
  primary: "#0D9488"
  accent: "#CCFBF1"
  background: "#18181C"
  surface: "#1F1F23"
  surface-highlight: "#27272B"
  text-primary: "#FAFAFA"
  text-secondary: "#A1A1AA"
  text-disabled: "#71717A"
  border: "#444449"
  border-subtle: "#343439"
  success: "#34D399"
  warning: "#F59E0B"
  error: "#EF4444"
typography:
  display: { fontFamily: Inter, fontSize: 24px, fontWeight: 600, lineHeight: 1.2 }
  heading-lg: { fontFamily: Inter, fontSize: 20px, fontWeight: 600, lineHeight: 1.3 }
  heading-md: { fontFamily: Inter, fontSize: 16px, fontWeight: 600, lineHeight: 1.4 }
  body-md: { fontFamily: Inter, fontSize: 14px, fontWeight: 400, lineHeight: 1.5 }
  body-sm: { fontFamily: Inter, fontSize: 13px, fontWeight: 400, lineHeight: 1.4 }
  label: { fontFamily: Inter, fontSize: 13px, fontWeight: 500, lineHeight: 1.2 }
  caption: { fontFamily: Inter, fontSize: 12px, fontWeight: 400, lineHeight: 1.4 }
  mono: { fontFamily: JetBrains Mono, fontSize: 12px, fontWeight: 400, lineHeight: 1.4 }
rounded:
  sm: 4px
  md: 8px
  lg: 12px
  xl: 16px
  full: 999px
spacing:
  xxs: 4px
  xs: 8px
  sm: 12px
  md: 16px
  lg: 24px
  xl: 32px
  xxl: 48px
components:
  primary-action:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.text-primary}"
    typography: "{typography.label}"
    rounded: "{rounded.md}"
    padding: 12px
  secondary-action:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text-primary}"
    typography: "{typography.label}"
    rounded: "{rounded.md}"
    padding: 12px
  library-card:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.md}"
    padding: 16px
---

# TapLoad

## Overview
The app is a practical media library and downloader. Screens should explain the current task plainly, keep the main action easy to find, and avoid decorative elements that compete with media or progress.

## Colors
Use semantic `AppColors` values so the UI follows the selected app theme. Midnight is the default reference palette above. Reserve the primary color for the current main action and use success, warning, and error only for real states.

## Typography
Use the shared Inter styles from `AppTypography`. Keep headings short and readable; use captions only for counts and supporting status.

## Layout
Use the shared 4/8/12/16/24/32/48 spacing scale. On desktop, use the available width for the library and keep controls in a compact toolbar. On mobile, keep touch targets at least 48dp and place frequent actions within comfortable reach. Let large catalogues scroll through lazy builders.

## Elevation & Depth
Prefer flat surfaces separated by subtle borders and the app's existing surface layers. Avoid new gradients, glows, or shadows for routine archive controls.

## Shapes
Use the existing 8px control radius and 12px panel radius. Keep cards and controls consistent within each screen.

## Components
- Show the primary task first; place infrequent actions behind a clearly named menu or in the import screen.
- A sync action stays in a pending state until data arrives or a clear error/timeout is reported.
- Selection actions appear only after selection; downloads report that items were queued, not that files are already complete.
- Explain imported data in plain language before showing technical file details.

## Do's and Don'ts
- Do use the existing theme, spacing, typography, and list components.
- Do distinguish an archive import from a live collection sync.
- Don't expose placeholder platforms, arbitrary batch sizes, or unfinished browsing modes as finished controls.
- Don't report success when an operation has only been requested.
