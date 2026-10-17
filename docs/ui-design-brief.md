# UI design brief: "Stylist" (working name)

Paste this whole file into a design tool or LLM and ask: *"Create 3 distinct visual directions for this app. For each, show the key screens in light and dark mode on a 390 x 844 phone."*

Everything below describes what the app does **today** (Flutter, Material 3). The current look is a plain, functional baseline with no brand identity yet: a purple-indigo accent, white cards and system fonts. Designers are free to replace colours, type and shapes, but should keep the **layout structure, tap-target sizes and accessibility rules** (section 2).

---

## 1. What the app is (prompt)

**Stylist is an AI personal stylist built on the clothes you already own.** You photograph your clothes, an AI recognises each piece (type, colours, pattern, how formal, which seasons) and fills in the details, you fix anything it got wrong with one tap, and the app builds a digital wardrobe you can browse and filter. Later phases (not designed yet) will suggest outfits from that wardrobe by weather and occasion, support couples, and add a paid plan.

* **Audience:** adults and teens 16+, mostly women and men who dress for work, dates and travel, and want less daily decision fatigue. Many are not tech-savvy; some use large text or a screen reader.
* **Promise:** "Dress with less thinking." Add a few pieces in under 20 seconds each, get a first outfit within minutes.
* **Tone:** warm, calm, personal, a little editorial. Think "a friend with good taste", not "a spreadsheet of clothes". Privacy is a selling point: photos are private, nothing is shared.
* **Platforms:** iPhone and Android, portrait phone first (reference 390 x 844 pt). Light and dark themes. US English.
* **Core feelings to design for:** quick (one-handed, few taps), reassuring (the AI shows what it is unsure about), tidy (a closet that looks beautiful as a grid of clean product-style photos).
* **Photos are the hero.** Every garment photo is cropped to a square on a neutral background, so the grid should feel like a boutique catalogue.

### The main journey

1. Welcome (3 slides) -> sign in with Google or "Try it first" (guest) -> age check (16+).
2. Style quiz (6 questions) -> a few basics (name, units, city; all optional).
3. Permission screens in context (camera, photos, location).
4. **Add your first 10 items** (camera, photo library, or "Use sample closet") with an unlock checklist and progress ring.
5. **First outfit reveal**: one big outfit plus two alternatives, each with a "why" line, and a Save button.
6. Two optional extras (invite a partner: placeholder; daily outfit time) -> Home.
7. Home -> **My closet** (grid), add item, review AI details, item detail, bulk add, settings and privacy.

---

## 2. Design system as built today

### 2.1 Colour tokens

| Role | Light | Dark |
|---|---|---|
| Primary (buttons, selected states, progress) | `#3D3A8C` (indigo) | `#B9B6FF` (lilac) |
| On primary (text on primary) | `#FFFFFF` | `#1C1A5C` |
| Surface (cards, sheets) | `#FFFFFF` | `#1B1B22` |
| Background (screen) | `#F7F7FA` | `#121218` |
| Text | `#1B1B22` | `#EDEDF4` |
| Muted text | `#5B5B6B` | `#B4B4C4` |
| Error / destructive | `#B3261E` | `#FFB4AB` |
| Outline (borders, unselected icons) | `#767686` | `#9A9AAC` |

Not customised yet (Flutter Material 3 defaults derived from the above): secondary container (used for the upload banner), error container, surface-container-highest (image placeholders, banners), outline-variant (card borders). A designer may define these freely.

**Garment colour palette (fixed, shared with the AI; 18 colours):**
black `#1A1A1A`, white `#FFFFFF`, grey `#8E8E93`, navy `#1B2A55`, blue `#1976D2`, light blue `#90CAF9`, teal `#00897B`, green `#388E3C`, olive `#6B6B2F`, yellow `#FBC02D`, orange `#F57C00`, red `#D32F2F`, burgundy `#7B1E3A`, pink `#F48FB1`, purple `#7B1FA2`, brown `#6B4A32`, beige `#D9C7A3`, cream `#F5EFE0`.
(The onboarding quiz uses a 14-colour subset: no light blue, teal, burgundy or cream.)

### 2.2 Typography (system font; one constant to change it)

| Style | Size / weight | Used for |
|---|---|---|
| Display small | 32 / 700 | Home greeting |
| Headline small | 24 (default) | Limit-reached title |
| Title large | 22 / 600 | Screen section titles, outfit card titles, empty-state titles |
| Title medium | 16 / 500 (default) | Field-group titles, closet count |
| Body large | 16 / 400 | Body text, chip labels |
| Body medium | 14 / 400 | Secondary text, hints |
| Body small | 12 / 400 | Captions |
| Label large | 14 / 600 | Tile names, small labels, banners |

All text must survive **200% system text size** without clipping (screens scroll or wrap instead).

### 2.3 Spacing, radius, motion

* Spacing scale: 4 (xs), 8 (sm), 16 (md), 24 (lg), 32 (xl), 48 (xxl).
* Corner radius: 8 (sm), 12 (md: buttons, inputs, tiles, photos), 20 (lg: quiz and outfit cards), 999 (pills, chips).
* **Minimum tap target: 48 x 48 dp** (everything tappable; iOS minimum 44 is also met).
* Page body: 24 px padding all round, content max width 560 (centred on tablets).
* Motion: fast 150 ms, medium 300 ms, slow 500 ms, curve ease-out-cubic. Used for the progress ring fill, carousel page dots and page changes.
* Elevation: effectively flat. Cards have 0 elevation and a 1 px outline; separation comes from borders and background contrast.

### 2.4 Accessibility rules (tested automatically; keep them)

* Text contrast WCAG AA (4.5:1 text, 3:1 outlines), in both themes.
* State is never colour alone: selected options also get a thicker border (2 px), a check icon and a spoken "selected".
* Every control has a text label for screen readers; icons are decorative unless they are buttons.
* Layout must not overflow at 100 / 150 / 200% text.

### 2.5 Standard components (reused across screens)

| Component | Spec |
|---|---|
| **Filled button** (primary action) | min 48 high, radius 12, primary fill, on-primary text, usually full width |
| **Outlined button** (secondary) | min 48 high, radius 12, 1 px outline |
| **Text button** (tertiary: Skip, Back, Not now) | min 48 x 48, radius 12, no fill |
| **Text field** | outlined, radius 12, floating label |
| **Option chip** (the main selection control in the closet) | pill (stadium), min 48 high x 48 wide, padding 16 x 4, 1 px outline unselected / 2 px primary outline + 12% primary fill + 18 px check icon when selected, optional 20 px colour dot at the left, label in body-large (700 weight when selected) |
| **Selectable tile** (quiz options) | rounded 12, min 56 high, padding 16 x 8, 1 px outline (2 px primary and 12% fill when selected), label left, circle / check-circle icon right, optional 24 px swatch at the left |
| **Field section** | titled group of option chips in a wrap (8 gap); title is a header; when the AI is unsure the section gets a 2 px error-coloured border (radius 12), a flag icon (18) and the words "Please check" |
| **Card** | radius 12 (cards on lists) or 20 (quiz / outfit), 0 elevation, 1 px outline-variant border, padding 16 |
| **List tile** | leading icon, title, optional subtitle, trailing chevron; min 48+ high |
| **Section header** | small bold label above a group of list tiles |
| **Bottom sheet** | rounded top, drag handle, safe-area padding, content scrolls (max 70 to 85% screen height) |
| **Alert dialog** | title, body, Cancel (text) + confirm (filled; red for destructive) |
| **Snack bar** | short confirmation or error at the bottom |
| **Offline banner** | full-width strip, surface-container-highest fill, centred label text, 8 padding |
| **Loading view** | centred circular spinner |
| **Error view** | centred 48 px error icon (error colour), message (body large, centred), "Retry" filled button; 24 padding |
| **Empty view** | centred message in body large, 24 padding |
| **Upload banner** | rounded 12 strip, min 48 high, 16 x 8 padding; secondary-container fill while uploading (20 px spinner or cloud-off icon + text), error-container fill with error icon when something failed; tap opens the upload sheet |

---

## 3. Screens: how many and what type

**25 full-screen pages + 8 overlays = 33 distinct views.**

| Group | Pages | Type |
|---|---|---|
| Entry / auth | Splash, Welcome (3-slide carousel), Sign-in, Age gate, Blocked (under 16) | 5 full screens |
| Onboarding | Style quiz (6 swipeable cards on one screen), Basics, Permissions (one reusable screen shown 4 times: camera, photos, location, notifications), First items, First outfit, Optional extras hub, Partner placeholder, Daily outfit time | 8 full screens |
| Home | Home | 1 full screen |
| Closet | My closet (grid), Capture (camera + preview states), Review details, Item detail, Bulk add (3 states), Limit reached (upgrade stub) | 6 full screens |
| Account | Settings, Consent centre ("Privacy choices"), Export my data, Delete my account, Restore account | 5 full screens |
| Overlays | Filters sheet, Upload queue sheet, "Sign in to save" sheet, Analytics-consent dialog, Sign-out dialog, Delete-item dialog, Time picker (system), Date picker (system) | 8 sheets, dialogs and system pickers |

Navigation: no bottom tab bar yet. Home is a launch pad with cards; the closet is pushed on top with a back arrow. (A designer may propose tabs: Home, Closet, Outfits, Profile.)

---

## 4. Every screen, its components and dimensions

Reference canvas **390 x 844**. "Body" means the standard page body (24 padding). All buttons are 48+ high, radius 12.

### 4.1 Splash
Full screen, centred **loading spinner** (default size ~40). If start-up fails: centred **Error view** with Retry. No branding yet: an obvious place for a logo.

### 4.2 Welcome (carousel)
* **Skip** text button, top right (48 x 48 min).
* **3 pages** (swipe): each is centred column: **96 px icon** (checkroom hanger, sparkle, sun; primary colour), 24 gap, **title** (title-large, centred), 16 gap, **body** (body-large, centred). 32 px top space.
  Copy: "Your wardrobe, styled" / "Outfits that feel like you" / "Dress with less thinking".
* **Page dots**: 8 px tall pills, active one 24 wide, inactive 8 wide, 4 px margin, primary vs outline colour. Pill radius.
* 24 gap, then **"Try it first"** (filled, full width) and 8 gap **"Sign in with Google"** (outlined, full width). A guest-only variant hides sign-in.

### 4.3 Sign-in (only when guest mode is off)
Centred scrolling column: title (headline), body text centred, 32 gap, **"Sign in with Google"** filled full width, error snack bar on failure.

### 4.4 Age gate
Centred column: title "Quick check" (title-large), body (explains 16+ and that only the confirmation is stored), 32 gap, **"I am 16 or older"** filled full width, 8 gap, **"I am under 16"** outlined full width. A one-time **analytics consent dialog** follows (see 4.27).

### 4.5 Blocked (under 16)
Centred: **72 px heart outline icon**, 24 gap, title "Thanks for stopping by", body centred (kind message, nothing was kept). No buttons.

### 4.6 Style quiz
* **Progress bar**: linear, full width, top of body, labelled "Question N of 6".
* 8 gap, question text (title-large).
* **Card area** (swipe through 6 cards): each card is a rounded **20 px** panel, padding 16, scrolls inside. Contains a question title, an optional hint (body-medium: "Pick as many as you like" etc.) and a column of **selectable tiles** with 8 gaps.
  1. Clothes shown: Menswear, Womenswear, Both, Everything (4 tiles, single choice, auto-advances).
  2. Fit: Relaxed, Regular, Slim (3 tiles, auto-advances).
  3. Colours: 14 tiles each with a **24 px round colour swatch** (multi-select; Next required).
  4. Never wear: Sleeveless, Shorts, Bright colours, Suits, Ties (menswear only), Hats, Heels (womenswear/both), Skirts, Dresses, Crop tops, plus "Nothing" (multi-select).
  5. Dress code: Very casual to Formal (5 tiles, single).
  6. Goals: Work, Dates, Travel, Everyday (multi-select; Finish button).
* 16 gap, bottom row: **Back** text button (left) and **Next / Finish** filled button (right), Next disabled until answered.

### 4.7 Basics
App bar "A few basics" with **Skip** action (text button). Scrolling form: intro text (body-large), 24 gap, **Name** text field, 16 gap, label "Units" (label-large) + **segmented control** (Imperial | Metric), 24 gap, **City** text field (hint "Start typing a city", helper text about privacy) with **suggestion list tiles** (place icon + city name) below, and an empty "no matches" line, 32 gap, **Continue** filled button.

### 4.8 Permissions (one screen, 4 variants)
Centred column, scrollable: **72 px icon** in primary colour (camera, photo library, location pin, bell), 24 gap, title (title-large, centred), 16 gap, body (centred, explains why), 32 gap, **Allow** filled button, 8 gap **Not now** text button. After the system prompt: a result line ("Camera is on" / explanation if denied), **Continue** filled button, and **Open Settings** text button when denied.

### 4.9 First items ("Add your first 10 items")
App bar title, no back. Scrolling body:
* Intro body-large.
* **Progress ring** centred, **140 x 140**, stroke width 10, animated 500 ms, with the text "N of 10 items" in the centre (label-large, centred, 16 padding).
* Title "To unlock your first outfit" (title-large).
* **Checklist rows** (each: 24 px icon, check-circle in primary when done, empty circle in outline when not, 8 gap, text "Tops: 0 of 2"): Tops 0/2, Bottoms 0/2, Shoes 0/1, then a small "or" label, then A dress 0/1, Shoes 0/1.
* Status text ("You can unlock your first outfit!" live-announced, or a hint).
* Buttons stacked with 8 gaps: **Use sample closet** (filled, hidden once unlocked), **Add with camera** (outlined, camera icon), **Add from photos** (outlined, library icon), optional **upload banner**, **See my first outfit** (filled; disabled until unlocked).

### 4.10 First outfit
App bar "Your first outfit". Scrolling list of **outfit cards**: the first is **prominent** (primary-coloured 2 px border), then a title "Two more ideas" (title-large, 16 top / 8 bottom), then 2 cards (1 px outline-variant border).
**Outfit card:** radius 20, flat, padding 16: heading "Outfit 1" (title-large); a row per item (24 px category icon in primary + item name like "Navy Jeans", body-large, 4 vertical padding); italic "why" line (body-medium: "Built around navy, one of your favourite colours."); right-aligned **Save outfit** text button with a bookmark icon (filled when saved). Empty state: title + message + "Back to items" button. Guests see the **"Sign in to save" sheet** (4.28).

### 4.11 Optional extras hub
App bar "Two optional extras". Body text, then two **list-tile cards** (radius 12): "Invite a partner" (group-add icon) and "Daily outfit time" (clock icon), each with subtitle and chevron. Shows "Set for 8:00 AM" once chosen. **Finish setup** filled button.

### 4.12 Partner placeholder
App bar. Centred: **72 px heart outline**, 24 gap, body text (coming soon), 32 gap, **Got it** filled button.

### 4.13 Daily outfit time
App bar. Body text, **Choose a time** outlined button with a clock icon (opens the system time picker), **Save time** filled button; then a notification **permission primer** (same layout as 4.8).

### 4.14 Home
App bar "Home" with a **settings gear icon button** (48 x 48) on the right. Offline banner if offline. Greeting "Hi, Ada" (display-small 32/700) or "Hi there", one line "Your stylist is getting ready." (placeholder for the future outfit-of-the-day), 16 gap, **My closet card** (radius 12, outlined, hanger icon left, title "My closet", subtitle "Browse, add and edit your clothes.", chevron right, 16 vertical padding), 24 gap, "Finish setting up" (title-large) then the two optional-extra cards (4.11).
**This is the screen most in need of design:** it is a stub waiting for the daily outfit suggestion.

### 4.15 My closet (grid)  *the main screen*
* **App bar**: title "My closet" (or a search field when searching), actions (48 x 48 each): search (magnifier / close), sort (menu with 5 options: Newest, Oldest, Recently edited, Most casual first, Most formal first), filters (tune icon with a small count badge), add several (collections icon).
* **Upload banner** (16 side margin) when photos are queued, uploading, offline or failed.
* **Summary card** (radius 12, outlined, padding 16, 16 side margin): row/wrap with "12 of 30 items" (title-medium) and "93 possible outfits" (label-large); an **8 px tall progress bar** (radius 4) for outfit potential; one line of advice ("Add a pair of shoes to unlock 31 more outfits." only when it would help, otherwise an encouraging line like "Your closet is filling out."); a red line when the free limit is reached.
* **Category chip row**: horizontally scrolling, **64 px tall**, 16 side padding, option chips: All, Top, Bottom, Outerwear, Footwear, Dress, Accessory.
* **Grid**: 16 padding, 8 gaps, tile aspect ratio **0.82** (taller than wide). Columns by width: 2 (< 360), 3 (360 to 599, e.g. 390 phone: about 112 x 137 tiles), 4 (600+), 5 (900+); one fewer column at large text.
* **Garment tile**: card radius 12, 1 px outline-variant border, clipped. Top: the square product photo filling the tile (50% opacity if archived or unavailable). Overlays: top-left **22 px circular badges** (white-surface circle, 14 px primary icon): heart = favourite, hourglass = unavailable, archive box = archived, flag = needs review (they stack left to right, 2 px apart); top-right **20 px spinner** while the AI is still working. Bottom: **name band**, min 48 high, 8 x 4 padding, name in label-large (up to 2 lines), e.g. "Navy Jeans".
* **Add item**: extended floating action button, bottom right, camera-plus icon + "Add item" (min 48 high).
* **States**: loading spinner; error view with Retry; **empty** (56 px hanger icon, "Your closet is empty", one line "Add your first item: one quick photo and we fill in the details."); **no matches** (56 px search-off icon, "Nothing matches these filters.", "Clear filters" text button); a thin loading bar under the grid while the next page loads; pull-to-refresh. 96 px empty space at the end so the floating button never covers a tile.

### 4.16 Filters (bottom sheet)
Handle, title "Filters" (title-large). Sections (each a field section of option chips): **Colour** (All + 18 colours with 20 px dots), **Season** (All, Spring, Summer, Autumn, Winter), **Formality** (a 2-thumb range slider 1 to 5 with the labels Loungewear, Casual, Smart casual, Business, Formal spoken to screen readers), **Availability** (All, Available, In the laundry, Lent out, At repair), a **Favourites only** switch row, **Archive** (Available, Archived only, All). Footer: **Clear filters** text button left, **Show N items** filled button right. Changes apply live to the grid behind.

### 4.17 Capture (camera)
App bar "Add an item" with a close (X) button.
* **Live camera preview** fills the area above the controls, cropped to the box.
* **Outline overlay**: a white 85%-opacity rounded rectangle (radius 24, 3 px stroke) at 70% of the preview width and height, centred, to line the garment up.
* **Hint strip** under the preview, full width, 16 padding, centred body-large: default "Lay it flat or hang it up on a plain background, in good light."; live variants "Too dark. Move somewhere brighter." and "Too bright. Step out of direct sun." (error-container fill) and "Lighting looks good.".
* **Control row** (16 padding): left **"Choose from photos"** text button with a library icon; centre **shutter** (72 px circle, primary fill, 4 px on-surface border, camera icon); right is a spacer.
* **Fallback** (no camera or permission denied): centred message, "Choose from photos" filled button, and "Open Settings" text button.

### 4.18 Capture (preview)
Black letterboxed photo area with the photo at its true aspect ratio; if the app finds a garment on a plain background, a **white 3 px crop rectangle** is drawn over it; a **switch row** "Crop to the item"; an error line if the photo cannot be read; a bottom row of two equal buttons: **Retake** (outlined) and **Use this photo** (filled). After tapping, a centred spinner with "Preparing your photo".

### 4.19 Review details  *where the AI result is corrected*
App bar "Check the details" with close. Scrolling body:
* **Upload banner** if the photo is not yet uploaded.
* **Photo box**: 240 high, full width, radius 12, image contained (shows the local photo until the processed one is ready; grey placeholder otherwise).
* **Status line** with live announcement: 20 px spinner (or info / error icon) + one sentence: "Uploading your photo. You can keep going." / "Looking at your photo. You can start filling things in now." / "We filled in the details. Fix anything that is off." / "We could not read this photo. Please fill in the details." / "Waiting for a connection. Your photo is saved and will upload automatically." Retry text button on failure.
* **Field sections** (option chips, **one tap changes a value**): Category (top, bottom, outerwear, footwear, dress, accessory); Type (only types for the chosen category and the user's menswear/womenswear setting, e.g. T-shirt, Shirt, Jeans, Sneakers...); Main colour (18 chips with dots); Second colour (None + 18); Pattern (Solid, Striped, Checked, Floral, Polka dot, Graphic, Animal print, Camouflage, Other); Formality (1 Loungewear to 5 Formal); Seasons (multi-select Spring, Summer, Autumn, Winter); Fit (None, Slim, Regular, Relaxed, Oversized); Material (None, Cotton, Linen, Wool, Cashmere, Silk, Denim, Leather, Suede, Polyester, Nylon, Knit, Fleece, Other).
  Fields where the AI was unsure (confidence under 70%) have the red flagged border + "Please check".
* **"Looks good"** filled button (disabled until the garment exists on the server) and **"Review later"** text button.

### 4.20 Item detail
App bar: title is the item name ("Navy Jeans"); actions: **favourite heart** toggle (outline / filled, 48 x 48) and a **more menu** (Analyse photo again, Delete item). Scrolling body:
* **Photo**: 280 high, radius 12, full width, contained.
* Optional error line (red) and "looking at your photo" line.
* The same **field sections** as 4.19.
* **Brand** text field (max 60 characters, counter) and **Notes** multiline field (3 lines, max 500).
* **Availability** field section: Available, In the laundry, Lent out, At repair; when not Available: "Back on Oct 20, 2026" text, **Set a return date** outlined button (opens the date picker), **Remove return date** text button.
* A note "Not used for outfits while it is unavailable or archived." when relevant.
* **Archive / Restore from archive** outlined button with an icon + a small explanatory caption.
* **Delete item** text button in the error colour with a trash icon; confirmation dialog (4.30).

### 4.21 Bulk add
App bar "Add several items" with close. Three states in one screen:
1. **Pick**: explanation ("Choose up to 20 photos. We upload them in the background and fill in the details."), "You have room for N more items." (label-large), **Choose photos** filled button with an icon.
2. **Progress**: headline "3 of 12 uploaded" (title-medium, live region) -> "All done", a full-width linear progress bar, the upload banner, a note if more than allowed were chosen.
3. **Review queue**: title "Ready to review" (title-large) + body, a row per photo: **56 x 56 thumbnail** (radius 8), name (body-large) and status (body-small: Analysing / Check details / Add details), chevron, min row height 64; then **Accept all** filled button (becomes "N items accepted"), and **Open my closet** outlined button when finished.

### 4.22 Limit reached (upgrade stub)
App bar with close. Centred column: **64 px hanger icon**, title "Your free closet is full" (headline-small, centred), body "The free plan holds 30 items. Paid plans are coming soon. For now you can archive or delete items to make room." (centred), 24 gap, **Manage my closet** filled button. (A real paid-plan paywall will replace this later.)

### 4.23 Settings
App bar "Settings". List with section headers: **Account** (guest: person icon + "Guest" + explanation + a **Sign in with Google** filled button; signed in: "Signed in as ada@example.com"), **Privacy** (Privacy choices, Privacy policy, Terms: icon leading, chevron/open trailing), **Your data** (Export my data, Delete my account in red), **Sign out**. Sign out opens a confirmation dialog.

### 4.24 Privacy choices (consent centre)
App bar. Two **switch rows** (Share anonymous usage data; "Don't use my photos to train AI", on by default), a location row (icon + explanation), and a small "Policy version 2026-01" line.

### 4.25 Export my data
App bar. Body text, then one state at a time: **Request export** filled button -> spinner + "Preparing..." -> "Your export is ready" + **Download and share** filled button -> or an error with Retry.

### 4.26 Delete my account
App bar. Warning body, a text field "Type DELETE to confirm", and a **Delete my account** filled button in the error colour, disabled until DELETE is typed.

### 4.27 Restore account
Centred column: title "Your account is scheduled for deletion", body, **Restore my account** filled button, **Sign out** text button.

### 4.28 Overlays
* **Analytics consent dialog**: "Help us improve" + explanation; Decline (text) / Allow analytics (filled).
* **Sign in to save sheet**: bottom sheet; title, body ("Create your account to keep this outfit and your closet on every device. Nothing you've done so far is lost."), **Continue with Google** filled, **Maybe later** text.
* **Upload queue sheet**: handle, title "Photo uploads", rows "N. filename.jpg" + state text (Waiting, Uploading + progress bar, Uploaded, Did not upload, Not accepted) with **Retry** and **Remove** text buttons.
* **Sign-out dialog** and **Delete-item dialog** (title, explanation, Cancel text + red filled confirm).
* **Time picker** and **date picker**: the platform's standard pickers.

---

## 5. Unique components and what they are for

| Component | Where | What it does for the user |
|---|---|---|
| **Carousel + page dots** | Welcome | Three value slides; dots show position, the active one stretches to 24 px |
| **Selectable tile** | Quiz | Big, forgiving answer targets with a clear selected state (border, check, spoken state) |
| **Colour swatch / colour dot** | Quiz, closet chips | Shows the actual colour next to its name; decorative only, the name is always read aloud |
| **Progress ring** | First items | Shows "N of 10" toward unlocking the first outfit; fills with an animation |
| **Unlock checklist** | First items | Plain-language rule (2 tops + 2 bottoms + shoes, or a dress + shoes) with ticks |
| **Outfit card** | First outfit | One recommended look: list of items, a "why" sentence, Save; the first is highlighted |
| **Permission primer** | Onboarding | Explains *why* before the OS prompt; handles allow, not now, denied (+ Open Settings) |
| **Garment tile** | Closet grid | Photo, name, status badges, spinner; one tap opens the item |
| **Status badges** | Grid tile | Heart (favourite), hourglass (unavailable), archive box, flag (needs a look) |
| **Summary / meter card** | Closet | Count vs plan limit, outfit potential bar, one useful suggestion |
| **Category chip row** | Closet | One-tap quick filter; the "All" chip resets |
| **Filter sheet + range slider** | Closet | Detailed filtering without leaving the grid; live results count on the apply button |
| **Upload banner / sheet** | Closet, review | Honest status of background uploads: uploading, waiting for network, failed with retry |
| **Camera outline overlay + lighting hint** | Capture | Helps people frame the garment and fix bad light before shooting |
| **Shutter button** | Capture | 72 px primary circle with a thick ring (iOS/Android camera convention) |
| **Crop suggestion** | Capture preview | White frame around the detected garment with a toggle to accept or ignore |
| **Option chip groups (field sections)** | Review, detail, filters | The core "one tap to correct the AI" control; wraps onto several lines; multi-select for seasons |
| **Low-confidence flag** | Review, detail, grid | Red border + flag + "Please check" so the user knows exactly what the AI doubted |
| **Review status line** | Review | Plain sentence for each stage: uploading, analysing, done, failed, offline |
| **Availability selector + return date** | Detail | Marks an item as in the laundry, lent or at repair, optionally with a date; it is then left out of outfits |
| **Bulk review queue + "Accept all"** | Bulk add | Add up to 20 at once, skim results, accept everything in one tap |
| **Limit screen** | Closet | Friendly stop at 30 free items, explains how to make room |
| **Switch rows** | Privacy choices | Opt-in analytics and "don't train AI on my photos" |
| **Typed confirmation field** | Delete account | Prevents accidental deletion: you must type DELETE |

---

## 6. Things a designer should know / decide

* There is **no logo, app icon design, illustration set or brand typeface** yet. The only imagery is the garment photos and 16 flat placeholder illustrations (sample closet).
* **Empty and first-run states matter**: the closet starts empty and the first-items screen is the activation moment. Illustration and tone have the most leverage here.
* **Garment photos are always square, on a neutral background**; they come in three sizes (200, 600, 1200 px). Design the grid for square product shots.
* The **Home screen is a placeholder**; the future centrepiece is "today's outfit" (weather + occasion). It is open for a bold proposal.
* Not built yet and **not part of this brief**: outfit generation screens, weather, couples/partner features, payments/paywall, admin tools.
* Keep it **one-handed**: primary actions in the lower half, the 72 px shutter and the extended "Add item" button are bottom-anchored.
* Dark mode is required, not optional.
