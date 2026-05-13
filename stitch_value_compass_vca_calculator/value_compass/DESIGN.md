---
name: Value Compass
colors:
  surface: '#0f131f'
  surface-dim: '#0f131f'
  surface-bright: '#353946'
  surface-container-lowest: '#0a0e1a'
  surface-container-low: '#171b28'
  surface-container: '#1b1f2c'
  surface-container-high: '#262a37'
  surface-container-highest: '#313442'
  on-surface: '#dfe2f3'
  on-surface-variant: '#bacac5'
  inverse-surface: '#dfe2f3'
  inverse-on-surface: '#2c303d'
  outline: '#859490'
  outline-variant: '#3c4a46'
  surface-tint: '#3cddc7'
  primary: '#57f1db'
  on-primary: '#003731'
  primary-container: '#2dd4bf'
  on-primary-container: '#00574d'
  inverse-primary: '#006b5f'
  secondary: '#c1c5dd'
  on-secondary: '#2b3042'
  secondary-container: '#414659'
  on-secondary-container: '#b0b4cb'
  tertiary: '#7cf0bc'
  on-tertiary: '#003825'
  tertiary-container: '#5fd3a1'
  on-tertiary-container: '#00593c'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#62fae3'
  primary-fixed-dim: '#3cddc7'
  on-primary-fixed: '#00201c'
  on-primary-fixed-variant: '#005047'
  secondary-fixed: '#dde1f9'
  secondary-fixed-dim: '#c1c5dd'
  on-secondary-fixed: '#161b2c'
  on-secondary-fixed-variant: '#414659'
  tertiary-fixed: '#85f8c4'
  tertiary-fixed-dim: '#68dba9'
  on-tertiary-fixed: '#002114'
  on-tertiary-fixed-variant: '#005137'
  background: '#0f131f'
  on-background: '#dfe2f3'
  surface-variant: '#313442'
typography:
  display-lg:
    fontFamily: manrope
    fontSize: 34px
    fontWeight: '700'
    lineHeight: 41px
    letterSpacing: -0.5px
  headline-md:
    fontFamily: manrope
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 30px
    letterSpacing: -0.3px
  body-lg:
    fontFamily: workSans
    fontSize: 17px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: -0.2px
  body-sm:
    fontFamily: workSans
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0px
  data-mono:
    fontFamily: ibmPlexSans
    fontSize: 16px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.2px
  label-caps:
    fontFamily: ibmPlexSans
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.5px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  margin-main: 20px
  gutter-grid: 12px
  stack-gap-lg: 24px
  stack-gap-md: 16px
  stack-gap-sm: 8px
  inset-card: 16px
---

## Brand & Style
The design system is engineered to evoke a sense of "Institutional Calm." It balances the high-density information architecture of professional Bloomberg terminals with the approachable, fluid aesthetics of modern iOS interfaces. The brand personality is precise, clinical, and authoritative, targeting sophisticated investors who value clarity over ornamentation.

The visual style follows a **Modern Corporate** movement with **Minimalist** sensibilities. It prioritizes the "Content is UI" philosophy, where data points themselves serve as the primary visual anchors. The interface utilizes a deep navy foundation to reduce ocular strain during extended sessions, using vibrant teal accents sparingly to signal growth and primary interaction paths.

## Colors
The color palette is built on a high-contrast foundation to ensure absolute legibility of financial metrics.

*   **Primary Background:** The system defaults to a Deep Navy (`#0A0E1A`), providing a more sophisticated and less abrasive alternative to pure black.
*   **Surface Layers:** Cards and containers use a lifted Navy (`#161B2C`) to create clear containment without the need for heavy borders.
*   **Accents:** Teal (`#2DD4BF`) is reserved for primary actions, success states, and positive market trends. Emerald Green (`#059669`) serves as a secondary semantic color for conservative growth signals.
*   **Typography:** Primary text is pure white (`#FFFFFF`) for maximum contrast, while secondary metadata uses a muted Slate (`#94A3B8`) to establish hierarchy.

## Typography
The typographic system utilizes a multi-font approach to maximize data density and readability. 

1.  **Manrope** is used for headers and display titles to provide a modern, balanced, and premium feel.
2.  **Work Sans** handles all body copy and descriptive text, chosen for its professional and grounded neutrality.
3.  **IBM Plex Sans** is employed for labels and numerical data; its structured, systematic design ensures that digits remain legible even at small scales.

For financial tables, use tabular lining figures (monospaced numbers) to ensure columns of data align perfectly for vertical scanning.

## Layout & Spacing
This design system employs a **Fluid Grid** optimized for iOS safe areas. The layout relies on a standard 4-column mobile grid with significant horizontal breathing room.

*   **Margins:** A 20px outer margin is maintained to prevent content from crowding the screen edges, reflecting a premium editorial feel.
*   **Padding:** Generous internal padding (16px) within cards ensures that dense financial data does not feel cluttered.
*   **Rhythm:** Vertical spacing follows an 8px base unit. Use 24px between distinct sections and 16px between related components. 
*   **Adaptivity:** On larger iOS devices (Pro Max/iPad), the grid expands while maintaining a centered maximum content width of 600px for readability.

## Elevation & Depth
In line with Apple’s Human Interface Guidelines, depth is conveyed through **Tonal Layering** rather than traditional drop shadows.

*   **Level 0 (Base):** Deep Navy (`#0A0E1A`).
*   **Level 1 (Cards/Plates):** Subtle Navy (`#161B2C`).
*   **Level 2 (Modals/Overlays):** A slightly lighter navy with a 20% opacity white border to define the edge against the background.

**Backdrop Blurs:** Use iOS "Ultra Thin" material blurs for navigation bars and tab bars to maintain context of the content scrolling beneath, ensuring the color of the blur is tinted toward the primary background color.

## Shapes
The shape language is sophisticated and "squircle" influenced, mimicking hardware radii. 

*   **Primary Containers:** Use a 16px radius (Rounded-LG equivalent) for main dashboard cards.
*   **Buttons & Inputs:** Use a 12px radius to maintain a consistent look while appearing slightly more compact.
*   **Charts:** Line graphs should use a subtle corner smoothing (0.5 tension) to avoid jagged peaks, reinforcing the "Calm" brand pillar.

## Components

*   **Buttons:** Primary buttons use a solid Teal fill with Deep Navy text. Secondary buttons are "Ghost" style with a 1px Slate border.
*   **Cards:** Dashboard cards should not have shadows. Use the Level 1 surface color and a 16px radius. Headers within cards should use `label-caps` for categorical labeling.
*   **Data Inputs:** Form fields use the Level 1 surface color with a 1px border that illuminates in Teal when focused.
*   **Positive/Negative Signals:** Growth metrics should use Teal text with a subtle 10% opacity Teal background pill. Negative metrics use a soft Coral Red (`#FB7185`) following the same pattern.
*   **Stock Tickers:** Use the `data-mono` type style for all ticker symbols and currency values to emphasize precision.
*   **Segmented Controls:** Follow the native iOS style but tinted to the Navy/Teal palette for seamless OS integration.