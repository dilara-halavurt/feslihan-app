# Feslihan Design Pattern
## "Annenin Yemek Defteri" - A Mother's Cookbook

---

## Design Vision

Feslihan should feel like opening your mother's well-loved recipe notebook — the one with flour-dusted pages, handwritten notes in the margins, and little hearts next to the dishes her family loves most. It's warm, personal, unhurried, and deeply familiar. Every screen should feel like a kitchen conversation, not a tech product.

**Core Emotional Pillars:**
- **Warmth** — like a kitchen filled with afternoon sunlight
- **Trust** — like your mother's handwriting, you just know it's right
- **Simplicity** — like a wooden spoon, it just works
- **Love** — every detail says "I made this for you"

---

## Color Palette

Moving from clinical green to a warm, kitchen-inspired palette. Think terracotta pots, wooden cutting boards, cream-colored recipe cards, and fresh herbs.

### Primary Colors

| Token | Name | Hex | Usage |
|-------|------|-----|-------|
| `cream` | Aged Paper | `#FFF8F0` | Primary background — like yellowed cookbook pages |
| `linen` | Linen | `#F5EDE3` | Secondary background — card surfaces, input fields |
| `parchment` | Parchment | `#EDE0D0` | Tertiary background — borders, dividers, subtle containers |

### Accent Colors

| Token | Name | Hex | Usage |
|-------|------|-----|-------|
| `basil` | Fresh Basil | `#4A7C59` | Primary accent — buttons, links, active states. Warmer than the current green. |
| `basilLight` | Basil Tint | `#E8F0E4` | Light accent background — selected states, badges, soft highlights |
| `basilDark` | Deep Herb | `#2E4F38` | Dark accent — cooking mode background, emphasis text |

### Warm Accents

| Token | Name | Hex | Usage |
|-------|------|-----|-------|
| `terracotta` | Terracotta | `#C67B5C` | Secondary accent — highlights, premium badges, warm CTAs |
| `honey` | Honey | `#E8A838` | Tertiary accent — stars, favorites, warning states |
| `tomato` | Tomato | `#D94F3B` | Destructive actions — delete, errors (sparingly) |

### Text Colors

| Token | Name | Hex | Usage |
|-------|------|-----|-------|
| `espresso` | Espresso | `#2C1810` | Primary text — like dark coffee ink on paper |
| `walnut` | Walnut | `#6B5244` | Secondary text — subtitles, descriptions, metadata |
| `oat` | Oat | `#A89585` | Tertiary text — placeholders, disabled states, timestamps |

### Utility

| Token | Name | Hex | Usage |
|-------|------|-----|-------|
| `flour` | Flour | `#FFFFFF` | Pure white — overlays, modals, cooking mode text |
| `shadow` | Cast Iron | `#2C1810` at 6% | Shadows — soft, warm-toned instead of cold black |

---

## Typography

The font strategy blends readability with personality. Handwritten touches appear only in decorative moments — never in body text or navigation. Everything should feel effortless to read.

### Font Stack

| Style | Spec | Usage |
|-------|------|-------|
| **Page Title** | Serif, 28pt, semibold | Screen titles — "Tariflerim", "Haftalik Plan" |
| **Section Header** | Rounded sans, 18pt, medium | Section dividers — "Malzemeler", "Yapilis" |
| **Card Title** | Rounded sans, 16pt, semibold | Recipe names on cards, list items |
| **Body** | System sans, 15pt, regular | Descriptions, instructions, paragraphs |
| **Label** | Rounded sans, 13pt, medium | Tags, badges, metadata, captions |
| **Caption** | System sans, 11pt, regular | Timestamps, fine print, counters |
| **Button** | Rounded sans, 15pt, medium | All button text |
| **Handwritten** | Serif italic, 14pt | Decorative only — empty states, tips, "anne notu" annotations |

### Font Choice Recommendation
- **Serif for titles**: Use a warm serif like Georgia or a custom serif (e.g., Lora, Playfair Display) for page titles only. This gives the cookbook feel.
- **Rounded sans for everything else**: System rounded (SF Rounded) keeps things friendly and readable.
- **Serif italic for annotations**: Small decorative moments — like a mother's handwritten note.

---

## Iconography

### Style
- **Line weight**: 1.5pt stroke, rounded caps and joins
- **Size**: 24x24 default, 20x20 compact, 32x32 feature icons
- **Style**: Warm, slightly organic — prefer filled variants with soft edges
- **Source**: SF Symbols, choosing the most organic/natural variant available

### Icon Map

| Feature | Icon | Notes |
|---------|------|-------|
| Tariflerim (My Recipes) | `book.closed.fill` | A closed cookbook |
| Meal Prep | `calendar` | Simple calendar, no fill |
| Ne Yesem? | `wand.and.stars` | Magic/discovery feel |
| Kilerim (Pantry) | `cabinet.fill` or `refrigerator.fill` | Pantry/storage |
| Alisveris Listesi | `basket.fill` | Warmer than cart |
| Add Recipe | `plus.circle.fill` | Floating action |
| Cooking Mode | `flame.fill` | Stove/cooking |
| Timer | `timer` | Cooking timer |
| Search | `magnifyingglass` | Standard |
| Filter | `line.3.horizontal.decrease` | Standard filter |
| Folder | `folder.fill` | Recipe organization |
| Heart/Favorite | `heart.fill` | Save/like |
| Delete | `trash` | Destructive |
| Share | `square.and.arrow.up` | Standard share |
| Settings | `gearshape` | Standard |
| Profile | `person.crop.circle` | User avatar fallback |
| Leaf (brand) | `leaf.fill` | Brand mark only — splash, app icon |
| Serving | `person.2` | People/servings |
| Nutrition | `chart.bar` | Macro display |
| Video | `play.rectangle.fill` | Video source link |
| Premium | `crown.fill` | Premium badge |

---

## Component Library

### 1. Recipe Card

The most important component. Should feel like a polaroid photo pinned to a corkboard or a recipe card from a box.

```
+-------------------------------+
|  [Recipe Photo]               |
|  (rounded corners, 3:2 ratio) |
|                               |
+-------------------------------+
|  Recipe Title              30m|
|  Cuisine tag  *  Difficulty   |
+-------------------------------+
```

- **Photo**: 3:2 aspect ratio, 12pt corner radius, subtle warm shadow
- **Title**: Card Title font, max 2 lines, `espresso` color
- **Metadata row**: `walnut` color, cooking time with flame icon, difficulty dots
- **Card background**: `flour` (white) with `shadow` drop shadow
- **Corner radius**: 14pt
- **Shadow**: `cast iron` color, 8pt radius, 4pt y-offset, 6% opacity
- **Hover/press**: Scale to 0.97 with spring animation
- **Layout**: 2-column grid, 12pt gap
- **Optional**: Tiny `heart.fill` in corner if favorited, `crown.fill` badge for premium recipes

### 2. Mode Selection Card

Large, inviting cards on the home screen. Each should feel like a chapter in a cookbook.

```
+-------------------------------------------+
|  [Icon]  32pt                             |
|                                           |
|  Mode Title          (Page Title font)    |
|  Short description   (Body font, walnut)  |
|                                           |
|                         [Arrow indicator] |
+-------------------------------------------+
```

- **Background**: `linen` with subtle border in `parchment`
- **Icon**: 32pt, `basil` color, left-aligned
- **Corner radius**: 16pt
- **Shadow**: Same warm shadow as recipe cards
- **Active/selected state**: `basilLight` background, `basil` border
- **Premium badge**: Small `crown.fill` icon in `terracotta` for gated features

### 3. Primary Button

```
+-------------------------------------------+
|          Button Label                      |
+-------------------------------------------+
```

- **Background**: `basil` solid fill
- **Text**: `flour` (white), Button font
- **Corner radius**: 12pt
- **Height**: 50pt
- **Shadow**: `basil` at 20% opacity, 6pt radius, 3pt y-offset
- **Pressed state**: Darken to `basilDark`, scale 0.98
- **Disabled state**: `parchment` background, `oat` text
- **Full-width** by default with 20pt horizontal padding

### 4. Secondary Button

- **Background**: `basilLight`
- **Text**: `basil`, Button font
- **Border**: None
- **Same dimensions as primary**
- **Pressed state**: Darken background slightly

### 5. Text Input Field

```
+-------------------------------------------+
|  Label                                    |
|  +---------------------------------------+|
|  | Placeholder text...                   ||
|  +---------------------------------------+|
+-------------------------------------------+
```

- **Background**: `linen`
- **Border**: 1pt `parchment`, becomes `basil` on focus
- **Corner radius**: 10pt
- **Height**: 46pt
- **Text**: `espresso`, Body font
- **Placeholder**: `oat`, Body font
- **Label above**: Label font, `walnut`

### 6. Tag / Badge / Chip

```
  [ Tag Label ]
```

- **Background**: `basilLight` (default), `linen` (inactive)
- **Text**: `basil` (default), `walnut` (inactive)
- **Corner radius**: 8pt (pill shape for small tags)
- **Padding**: 8pt horizontal, 4pt vertical
- **Font**: Label font
- **Selected state**: `basil` background, `flour` text
- **Variants**: Cuisine tags, difficulty, cooking time, diet type

### 7. Section Divider

Instead of hard lines, use a subtle botanical ornament or just generous spacing.

- **Option A**: 1pt line in `parchment` with 24pt vertical margin
- **Option B**: Small centered leaf ornament (`leaf.fill` at 10pt in `parchment`) with lines extending left and right
- **Option C**: Just 32pt of vertical spacing (preferred for most cases)

### 8. Bottom Sheet / Modal

- **Background**: `cream`
- **Handle**: `parchment` colored pill, 36x4pt, centered
- **Corner radius**: 20pt (top corners only)
- **Shadow**: Large warm shadow above
- **Content padding**: 20pt horizontal, 16pt top (below handle)

### 9. Navigation Bar

- **Style**: Transparent / blurred background
- **Title**: Page Title font, `espresso`, left-aligned
- **Back button**: Circular, `flour` background with warm shadow, `espresso` chevron
- **Right actions**: Icon buttons in `walnut`, 24pt

### 10. Tab Bar / Mode Switcher

The home screen uses a custom mode switcher, not a standard tab bar. Keep this pattern but make it warmer.

- **Active tab**: `basil` text, 2pt `basil` underline or filled pill background
- **Inactive tab**: `oat` text
- **Background**: `cream`
- **Font**: Section Header font

### 11. Empty State

```
+-------------------------------------------+
|                                           |
|           [Illustration area]             |
|                                           |
|        "Henuz tarif eklemediniz"          |
|    "Bir video linki ile baslayin..."      |
|                                           |
|        [ Add First Recipe ]               |
|                                           |
+-------------------------------------------+
```

- **Illustration**: Simple, warm line art (a pot, a spoon, a recipe card)
- **Title**: Section Header font, `espresso`
- **Subtitle**: Body font, `walnut`, serif italic (handwritten feel)
- **CTA**: Primary button
- **Centered layout with generous vertical spacing**

### 12. Floating Action Button (FAB)

- **Size**: 56x56pt
- **Background**: `basil`
- **Icon**: `plus` in `flour`, 22pt, bold weight
- **Shadow**: `basil` at 25% opacity, 10pt radius, 5pt y-offset
- **Position**: Bottom-right, 20pt from edges
- **Animation**: Subtle breathing scale animation (1.0 to 1.03, 2s loop)

### 13. Cooking Mode Step Card

Full-screen immersive cooking experience.

```
+-------------------------------------------+
|  Step 3 / 8              [X close]        |
|  ═══════════════════                      |  (progress bar)
|                                           |
|                                           |
|  "Sogani ince ince dograyip               |
|   zeytinyaginda kavurun.                  |
|   Pembelesinceye kadar                    |
|   karistirin."                            |
|                                           |
|                                           |
|           [ 5:00 Timer ]                  |
|                                           |
|  [<< Previous]          [Next >>]         |
+-------------------------------------------+
```

- **Background**: `basilDark` (deep herb green)
- **Text**: `flour` (white), 22pt, medium weight, generous line height (1.6)
- **Step counter**: `oat`-equivalent light muted color
- **Progress bar**: `basil` on dark track
- **Timer button**: `terracotta` pill with countdown
- **Navigation**: Large tap targets, bottom-aligned
- **Close button**: Top-right, subtle

### 14. Swipe Card (Ne Yesem Results)

Tinder-style recipe discovery cards.

- **Card size**: Full-width minus 32pt, 4:5 aspect ratio
- **Photo**: Top 60% of card
- **Info area**: Bottom 40%, `flour` background
- **Title**: Card Title font, `espresso`
- **Tags**: Cooking time, cuisine, difficulty as chips
- **Swipe left (reject)**: Card fades with red tint
- **Swipe right (save)**: Card fades with green tint, heart animation
- **Shadow**: Elevated warm shadow

### 15. Wizard Step Indicator

Used in Meal Prep (7 steps) and Ne Yesem (4 steps).

```
  [*]---[*]---[*]---[ ]---[ ]---[ ]---[ ]
```

- **Completed step**: `basil` filled circle, 8pt
- **Current step**: `basil` circle with `basilLight` glow ring, 10pt
- **Upcoming step**: `parchment` circle, 8pt
- **Connecting line**: `parchment`, 2pt
- **Alternative**: Simple "Step 3 of 7" text in `walnut` with a linear progress bar below

### 16. Ingredient Row

```
  Sogan               2 adet        [basket icon]
```

- **Name**: Body font, `espresso`
- **Amount**: Body font, `walnut`, right-aligned
- **Availability icon**: Small colored dot (green = have it, orange = maybe, red = need to buy)
- **Price tier**: Small `$` symbols in `honey`
- **Divider**: 1pt `parchment` or none (use spacing)
- **Height**: 44pt minimum tap target

### 17. Meal Plan Day Card

```
+-------------------------------------------+
|  Pazartesi                    12 Ocak     |
|  -----------------------------------------|
|  Kahvalti    Menemen                      |
|  Ogle        Mercimek Corbasi + Salata    |
|  Aksam       Karniyarik                   |
|  -----------------------------------------|
|  ~1,800 kcal                              |
+-------------------------------------------+
```

- **Background**: `flour` card on `cream` background
- **Day name**: Section Header font, `espresso`
- **Date**: Label font, `oat`
- **Meal rows**: Body font, meal type in `walnut`, recipe name in `espresso`
- **Calorie footer**: Caption font, `oat`
- **Corner radius**: 14pt
- **Shadow**: Standard warm shadow

### 18. Pantry Bubble

The bubble selection UI for adding pantry ingredients.

- **Unselected**: `linen` background, `walnut` text, `parchment` border
- **Selected**: `basil` background, `flour` text
- **Size**: Dynamic based on text length
- **Corner radius**: Full pill (height/2)
- **Animation**: Spring bounce on selection
- **Layout**: Flowing wrap layout

### 19. Shopping List Item

```
  [ ]  Sogan                    2 adet    [x]
  [v]  Domates                  500g      [x]
```

- **Unchecked**: Open circle in `parchment`, `espresso` text
- **Checked**: Filled circle with checkmark in `basil`, `oat` text with strikethrough
- **Delete**: `tomato` X icon, appears on swipe
- **Height**: 48pt

### 20. Paywall / Premium Card

```
+-------------------------------------------+
|                                           |
|  [crown icon]  Feslihan+                  |
|                                           |
|  * 30 tarif / ay                          |
|  * Haftalik yemek plani                   |
|  * Ne Yesem? onerisi                      |
|                                           |
|  30 TL / ay                               |
|                                           |
|  [ Basla ]                                |
|                                           |
+-------------------------------------------+
```

- **Background**: Gradient from `linen` to `cream`
- **Crown icon**: `terracotta`
- **Plan name**: Page Title font, `espresso`
- **Features list**: Body font with `basil` checkmarks
- **Price**: Section Header font, `terracotta`
- **CTA**: Primary button
- **Selected plan**: `basil` border, `basilLight` background tint
- **Corner radius**: 16pt

---

## Layout & Spacing

### Spacing Scale (8pt grid)

| Token | Value | Usage |
|-------|-------|-------|
| `xs` | 4pt | Inline spacing, icon-to-text gap |
| `sm` | 8pt | Tight spacing, within compact components |
| `md` | 12pt | Default spacing between related elements |
| `base` | 16pt | Standard content padding, between components |
| `lg` | 20pt | Screen edge padding, section spacing |
| `xl` | 24pt | Between sections |
| `2xl` | 32pt | Major section breaks |
| `3xl` | 48pt | Top-of-screen breathing room |

### Screen Layout Rules

- **Screen edge padding**: 20pt horizontal (consistent everywhere)
- **Card grid gap**: 12pt
- **Section gap**: 24pt
- **Content top padding**: 16pt below nav bar
- **Safe area**: Always respect, add 16pt extra bottom padding above home indicator
- **Maximum content width**: 390pt (scale naturally on larger iPads)

### Corner Radius Scale

| Size | Value | Usage |
|------|-------|-------|
| `sm` | 8pt | Tags, chips, small badges |
| `md` | 12pt | Buttons, inputs, small cards |
| `lg` | 14pt | Recipe cards, content cards |
| `xl` | 16pt | Mode cards, large containers |
| `2xl` | 20pt | Sheets, modals |
| `full` | height/2 | Pills, avatars, circular buttons |

---

## Animation & Motion

### Principles
- **Ease and warmth**: Use spring animations with moderate damping (0.7-0.8). Nothing should feel sharp or mechanical.
- **Subtle is better**: Animations enhance, never distract.
- **Meaningful**: Every animation should communicate something (feedback, transition, state change).

### Specific Animations

| Element | Animation | Spec |
|---------|-----------|------|
| Screen transitions | Slide + fade | 0.35s spring, 0.8 damping |
| Card press | Scale down | 0.97 scale, 0.2s spring |
| Card appear (grid) | Fade up | 0.3s, staggered 0.05s per item |
| FAB | Breathing pulse | 1.0-1.03 scale, 2s ease-in-out loop |
| Tab switch | Cross-fade | 0.25s ease |
| Sheet present | Slide up + backdrop fade | 0.35s spring |
| Cooking step change | Slide left/right + fade | 0.3s spring |
| Swipe card | Physics-based drag | Rotation follows drag, velocity-based throw |
| Wizard step | Slide + scale | 0.4s spring, new step scales from 0.95 |
| Toggle/check | Checkmark draw + bounce | 0.3s spring with overshoot |
| Pantry bubble select | Scale bounce | 1.0 > 1.1 > 1.0, 0.3s spring |
| Timer tick | None (text only) | Smooth countdown |
| Loading states | Pulsing shimmer | Warm-toned skeleton (linen to parchment) |

---

## Screen-by-Screen Design Notes

### 1. Splash Screen
- Centered leaf icon (large, `basil` color) with app name below
- Tagline in serif italic: "Anne, ne yesek?"
- Background: `cream`
- Leaf grows from small to full size with spring animation
- Transitions to home with a warm fade

### 2. Login / Sign Up
- Minimal, centered layout
- Large leaf icon at top
- "Feslihan" in serif Page Title font
- Tagline below in serif italic
- Two buttons: "Giris Yap" (primary), "Kayit Ol" (secondary)
- Background: `cream`
- The leaf and name should feel like a cookbook cover

### 3. Home / Mode Selection
- Profile avatar in top-right corner (or top-left with greeting: "Merhaba, Neslihan")
- 5 mode cards stacked vertically with generous spacing
- Each card: icon + title + one-line description + arrow
- Cards use `linen` background
- Premium badge on Meal Prep card
- Bottom area: saved recipe count, pantry count as subtle stats
- No tab bar — this IS the hub, each mode is a full-screen push

### 4. Recipe List (Tariflerim)
- Top: Page Title "Tariflerim" with search icon
- Search bar: `linen` background, appears on icon tap (animated expand)
- Folder carousel: Horizontal scroll of folder pills below search
- Recipe grid: 2-column, recipe cards as designed above
- Filter button: Floating pill in top area "Filtrele" with active filter count badge
- Sort: Dropdown or segmented control near filter
- Empty state: Warm illustration + serif italic prompt
- FAB for adding new recipe (bottom-right)

### 5. Recipe Detail
- Hero image: Full-width, edge-to-edge, with gradient overlay at bottom for title
- Title overlaid on hero bottom, `flour` color
- Creator row: Small avatar + name + platform icon (below hero)
- Serving adjuster: Horizontal pill selector (0.5x through 6x)
- 3-tab content area (Malzemeler / Yapilis / Besin):
  - Tabs styled as underlined text, not iOS segmented control
  - Active tab: `basil` with underline
  - Ingredients tab: List with amounts, availability dots
  - Instructions tab: Numbered steps, generous line height
  - Nutrition tab: Macro cards (calories, protein, carbs, fat, fiber) as small tiles
- Bottom bar: "Pisirmeye Basla" primary button + "Videoyu Ac" secondary button
- Back button: Floating circular back button over hero image

### 6. Add Recipe (Video URL Input)
- Sheet modal from bottom
- Title: "Tarif Ekle"
- URL input field with paste button
- Supported platforms shown as small icons (TikTok, Instagram, X)
- Processing states shown as a vertical checklist:
  - Each step gets a checkmark when done
  - Current step has a pulsing dot
  - Steps: Video bilgileri, Ses cikartma, Yazi cevirme, Tarif analizi
- Result preview: Mini recipe card showing extracted data
- "Kaydet" primary button when done

### 7. Meal Prep Wizard
- Full-screen flow (modal)
- Progress bar at very top (thin, `basil`)
- Each step: centered content with large, tappable option cards
- Step title at top in Page Title font
- Options as large selection cards (single or multi-select depending on step)
- Selected cards: `basil` border + `basilLight` fill + checkmark
- "Devam" (Continue) button at bottom, disabled until selection made
- Back arrow in top-left
- Final step (result): Day-by-day meal plan cards, scrollable

### 8. Ne Yesem? (What to Eat)
- Same wizard pattern as Meal Prep but 4 steps
- Final step: Swipe card interface
  - Stack of recipe cards
  - Swipe right = save, swipe left = skip
  - Visual feedback: green/red tint as card drags
  - Below cards: small "like" and "skip" buttons for non-swipe users
  - "X recipe saved" counter at bottom

### 9. Pantry
- Page Title: "Kilerim" with item count badge
- Search bar at top
- Ingredients listed as tags/bubbles in a flowing layout (not a list)
- Grouped by category if possible (sebzeler, meyveler, baharatlar, etc.)
- "Ekle" button opens bubble selection sheet
- Bubble sheet: Category tabs at top, ingredient bubbles below, tap to toggle
- Selected bubbles: `basil` fill, unselected: `linen` fill

### 10. Shopping List
- Page Title: "Alisveris Listesi"
- Two sections with headers: "Alinacaklar" and "Alinanlar"
- Each item: checkbox + name + amount + delete (swipe)
- Checked items: strikethrough, muted colors
- Add button: At bottom of "Alinacaklar" section, inline "+" row
- Clear completed: Text button below "Alinanlar" section

### 11. Cooking Mode
- Full-screen, immersive, dark theme (`basilDark` background)
- Large instruction text, centered, comfortable reading
- Step counter and progress bar at top
- Timer (when applicable): Large `terracotta` pill with countdown
- Previous/Next as large bottom buttons
- Close X in top corner
- No distractions — this is focused, calm, guiding

### 12. Paywall
- Sheet modal
- Two plan cards side by side or stacked
- Current plan indicated with badge
- Feature lists with `basil` checkmarks
- Price prominent in `terracotta`
- CTA button for each plan
- "Restore purchases" text link at bottom

---

## Micro-Interactions & Delight

These small touches make the app feel alive and loved:

1. **Recipe saved**: Brief confetti of small leaf particles
2. **Cooking complete**: Gentle celebration animation (sparkles or checkmark burst)
3. **Pantry milestone (30 items)**: Unlocking animation — "Kileriniz hazir!" with key turning
4. **Empty search**: Handwritten-style "Hmm, bulamadim..." text
5. **Pull to refresh**: A small pot that fills with steam as you pull
6. **Meal plan generated**: Cards deal out one by one like dealing recipe cards
7. **Swipe save in Ne Yesem**: Heart floats up from the card
8. **First recipe added**: "Ilk tarifiniz! Harika!" toast with leaf icon

---

## Accessibility

- All text meets WCAG AA contrast ratio (4.5:1 for body, 3:1 for large text)
- `espresso` (#2C1810) on `cream` (#FFF8F0) = 13.5:1 ratio (passes AAA)
- `walnut` (#6B5244) on `cream` (#FFF8F0) = 5.2:1 ratio (passes AA)
- `basil` (#4A7C59) on `flour` (#FFFFFF) = 4.6:1 ratio (passes AA)
- Minimum touch targets: 44x44pt
- Support Dynamic Type scaling
- VoiceOver labels on all interactive elements
- Reduce Motion: Replace springs with fades, disable parallax

---

## Dark Mode Considerations

If dark mode is supported in the future:

| Light Token | Dark Equivalent |
|-------------|-----------------|
| `cream` (#FFF8F0) | `#1C1412` (warm dark brown) |
| `linen` (#F5EDE3) | `#2A211B` (dark linen) |
| `parchment` (#EDE0D0) | `#3D3028` (dark parchment) |
| `espresso` (#2C1810) | `#F5EDE3` (linen becomes text) |
| `walnut` (#6B5244) | `#A89585` (oat becomes secondary) |
| `basil` (#4A7C59) | `#6AAF7B` (lighter basil for dark bg) |

Keep the warmth — dark mode should feel like cooking by candlelight, not a dark IDE.

---

## Design Tokens Summary (for implementation)

```
COLORS:
  background.primary:    #FFF8F0  (cream / aged paper)
  background.secondary:  #F5EDE3  (linen)
  background.tertiary:   #EDE0D0  (parchment)

  accent.primary:        #4A7C59  (basil)
  accent.primaryLight:   #E8F0E4  (basil tint)
  accent.primaryDark:    #2E4F38  (deep herb)

  accent.secondary:      #C67B5C  (terracotta)
  accent.tertiary:       #E8A838  (honey)
  accent.destructive:    #D94F3B  (tomato)

  text.primary:          #2C1810  (espresso)
  text.secondary:        #6B5244  (walnut)
  text.tertiary:         #A89585  (oat)

  surface.white:         #FFFFFF  (flour)
  shadow.color:          #2C1810 @ 6%

TYPOGRAPHY:
  pageTitle:     serif, 28pt, semibold
  sectionHeader: rounded, 18pt, medium
  cardTitle:     rounded, 16pt, semibold
  body:          system, 15pt, regular
  label:         rounded, 13pt, medium
  caption:       system, 11pt, regular
  button:        rounded, 15pt, medium
  handwritten:   serif italic, 14pt

SPACING:
  xs: 4   sm: 8   md: 12   base: 16   lg: 20   xl: 24   2xl: 32   3xl: 48

RADIUS:
  sm: 8   md: 12   lg: 14   xl: 16   2xl: 20   full: height/2

SHADOW:
  card:    0 4 8 #2C1810/6%
  button:  0 3 6 accent/20%
  float:   0 5 10 #2C1810/10%

ANIMATION:
  spring.default:  duration 0.35, damping 0.8
  spring.bouncy:   duration 0.3, damping 0.6
  fade:            duration 0.25, ease
```

---

## Complete Feature Inventory (No Functionality Loss)

Every feature from the current app that must be preserved:

- [ ] Authentication (login/signup via Clerk)
- [ ] Animated splash screen
- [ ] Mode selection hub (5 modes)
- [ ] Recipe grid with search, filter, sort
- [ ] Folder organization for recipes
- [ ] Recipe detail with ingredients/instructions/nutrition tabs
- [ ] Serving size multiplier
- [ ] Recipe creator profile links
- [ ] Video URL recipe import with AI processing
- [ ] Cooking mode (step-by-step, timers)
- [ ] Meal Prep wizard (7 steps) with AI generation
- [ ] Saved meal plans list
- [ ] Meal editing within plans
- [ ] Ne Yesem wizard (4 steps) with swipe results
- [ ] Pantry management with bubble add UI
- [ ] Shopping list with check/uncheck
- [ ] Paywall with two subscription tiers
- [ ] Premium feature gating (meal prep, quotas)
- [ ] Pantry gating (30 item minimum)
- [ ] Backend sync (recipes, folders, pantry, shopping list, meal plans)
- [ ] Monthly recipe quota tracking
- [ ] Recipe cost estimation
- [ ] Account/profile sheet
