---
name: Sabotaypro
colors:
  surface: '#f7f9fb'
  surface-dim: '#d8dadc'
  surface-bright: '#f7f9fb'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f2f4f6'
  surface-container: '#eceef0'
  surface-container-high: '#e6e8ea'
  surface-container-highest: '#e0e3e5'
  on-surface: '#191c1e'
  on-surface-variant: '#44474d'
  inverse-surface: '#2d3133'
  inverse-on-surface: '#eff1f3'
  outline: '#75777e'
  outline-variant: '#c5c6cd'
  surface-tint: '#515f78'
  primary: '#000000'
  on-primary: '#ffffff'
  primary-container: '#0d1c32'
  on-primary-container: '#76849f'
  inverse-primary: '#b9c7e4'
  secondary: '#006c49'
  on-secondary: '#ffffff'
  secondary-container: '#6cf8bb'
  on-secondary-container: '#00714d'
  tertiary: '#000000'
  on-tertiary: '#ffffff'
  tertiary-container: '#0b1c30'
  on-tertiary-container: '#75859d'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d6e3ff'
  primary-fixed-dim: '#b9c7e4'
  on-primary-fixed: '#0d1c32'
  on-primary-fixed-variant: '#39475f'
  secondary-fixed: '#6ffbbe'
  secondary-fixed-dim: '#4edea3'
  on-secondary-fixed: '#002113'
  on-secondary-fixed-variant: '#005236'
  tertiary-fixed: '#d3e4fe'
  tertiary-fixed-dim: '#b7c8e1'
  on-tertiary-fixed: '#0b1c30'
  on-tertiary-fixed-variant: '#38485d'
  background: '#f7f9fb'
  on-background: '#191c1e'
  surface-variant: '#e0e3e5'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
  mono-data:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.05em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  xs: 4px
  sm: 12px
  md: 16px
  lg: 24px
  xl: 32px
  container-margin: 20px
  gutter: 16px
---

## Brand & Style

The design system is engineered for high-stakes financial environments where precision and trust are paramount. The personality is authoritative yet modern, stripping away unnecessary ornamentation to focus on clarity and transactional efficiency. 

The aesthetic follows a **Corporate / Modern** style with a focus on high-density information display. It leverages a "Security First" visual language—utilizing deep, stable tones paired with vibrant success indicators to provide immediate psychological feedback for financial actions. The interface maintains a professional rigor through structured alignment, ample whitespace for legibility, and a sophisticated use of depth to separate navigation from core transactional data.

## Colors

This color palette is designed to balance institutional stability with digital-native dynamism.

- **Primary (Deep Navy):** Used for primary navigation, headers, and high-emphasis buttons to establish authority.
- **Secondary (Emerald Green):** Reserved exclusively for positive financial growth, successful transaction states, and primary call-to-action triggers (e.g., "Collect Payment").
- **Tertiary (Slate Gray):** Utilized for secondary text, icons, and non-interactive metadata to reduce visual noise.
- **Surface & Backgrounds:** A range of ultra-light grays (#F8FAFC to #F1F5F9) are used to distinguish different data modules without resorting to heavy borders.
- **Error States:** Use a sharp Crimson (#EF4444) to contrast against the Emerald success color, ensuring immediate recognition of failed payments or alerts.

## Typography

The typography system relies entirely on **Inter** to ensure maximum legibility across mobile and desktop resolutions. 

Numerical data is the most critical element of the UI; for account balances and transaction amounts, use `headline-lg` with a slightly tighter letter spacing. For secondary labels (e.g., "Account Number" or "Timestamp"), use `label-sm` with an uppercase transform to create a clear visual hierarchy between the data and its description. 

Text colors should strictly follow the color system: `primary` for headlines, `tertiary` (Slate) for body copy, and `secondary` (Emerald) for positive monetary values.

## Layout & Spacing

The layout is built on an **8px linear scale**, ensuring consistent vertical rhythm across all screens. 

- **Mobile:** Uses a single-column fluid layout with a `container-margin` of 20px. 
- **Desktop:** Utilizes a 12-column fixed grid with a max-width of 1280px.
- **Information Density:** For data-heavy lists (transactions), use the `sm` (12px) spacing unit for vertical padding between rows. For marketing or dashboard overviews, use `lg` (24px) or `xl` (32px) to allow the UI to breathe.

Cards and data modules should use the `md` (16px) gutter to maintain a clear separation of concerns.

## Elevation & Depth

This design system uses a **Tonal Layering** approach combined with **Ambient Shadows** to create a sense of physical organization.

1.  **Background (Level 0):** The base canvas uses the `neutral` color (#F8FAFC).
2.  **Surface (Level 1):** Primary cards and containers use a pure White (#FFFFFF) background with a very soft, diffused shadow: `0 4px 6px -1px rgb(0 0 0 / 0.05), 0 2px 4px -2px rgb(0 0 0 / 0.05)`.
3.  **Active/Floating (Level 2):** Modals, dropdowns, and floating action buttons use a more pronounced shadow to indicate they are closer to the user: `0 10px 15px -3px rgb(0 0 0 / 0.1)`.

Avoid using heavy borders. Instead, use subtle 1px strokes in a light slate tone (#E2E8F0) only when multiple white surfaces overlap.

## Shapes

The shape language is defined as **Rounded**, conveying a modern and approachable feel without appearing informal.

- **Buttons & Inputs:** Use the standard `rounded` (0.5rem) setting.
- **Cards & Modals:** Use `rounded-lg` (1rem) to create a clear "container" feel.
- **Status Tags/Chips:** Use `rounded-xl` (1.5rem) or fully pill-shaped styles to differentiate them from interactive buttons.

This consistent rounding softens the high-contrast professional color palette, making the app feel sophisticated rather than rigid.

## Components

### Buttons
- **Primary:** Deep Navy (#0A192F) background, white text. No shadow on idle, subtle lift on hover.
- **Success/Action:** Emerald Green (#10B981) for "Collect" or "Confirm" actions.
- **Secondary:** White background with a Slate (#CBD5E1) 1px border.

### Input Fields
- High-contrast white backgrounds with a subtle gray border (#E2E8F0).
- **Focus State:** 2px solid Deep Navy border.
- Floating labels are preferred for mobile to maximize space.

### Cards
- White background, `rounded-lg` corners, and Level 1 shadow. 
- Use a 4px vertical Emerald Green accent bar on the left edge of cards that represent "Active Collections" or "Paid" status.

### Status Chips
- **Paid/Success:** Light emerald background (10% opacity) with dark emerald text.
- **Pending/Processing:** Light blue-gray background with slate text.
- **Overdue/Alert:** Light red background with crimson text.

### Lists
- Use horizontal dividers (#F1F5F9) between transaction items.
- Chevron icons should be Slate Gray to indicate drill-down capability without drawing focus away from the primary data.