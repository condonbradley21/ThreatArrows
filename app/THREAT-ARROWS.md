# Threat Arrows — WoW Forever (interface 16001)

Close the game. Run Install-ThreatArrows.cmd and choose the Forever folder containing WowB.exe or Wow.exe. This copies only Interface/AddOns/ThreatArrows; existing addons and WTF settings are preserved. Updates delivered to the healing app do not replace a running game addon: close WoW and rerun this installer to install an addon update.

Launch WoW and enable Threat Arrows in the character screen AddOns list. Turn on enemy nameplates (normally V). The arrows sit above visible hostile NPC nameplates, including mobs you are not targeting; nameplate range/visibility limits still apply.

- Shaded, dark-outlined arrows use 65% opacity for slight transparency.
- White outlined text uses Details Tiny Threat's convention: the current tank is 100%; other players use raw threat percentage relative to the tank, with scaled percentage as a fallback. Values above 100 are preserved in text; color caps at green. Selected mobs are queried as target first, then by nameplate token. Restricted percentages are passed directly to WoW's SetFormattedText without comparison or arithmetic. `?` means the call or UI formatting failed, or there is no percentage.
- Only the selected target's arrow bounces vertically (0.9-second cycle); other arrows stay still. The selected idle enemy has a gray arrow.
- When the client exposes readable threat percentage: red at 0%, orange at 25%, yellow at 50%, yellow-green at 75%, bright green at 100%. This is relative threat, not your share of all threat; 100% is not a guarantee of a secure lead.
- If percentages are restricted, the number can still display while the color uses available threat states. If percentages are unavailable, the same state colors apply: green = secure (3), orange = insecure tanking (2), red = not tanking (0/1) or another known tank. Gray = unknown/restricted threat. No estimated percentage is substituted.
- Hidden: idle unselected mobs, players, friendly/dead units, or unreadable eligibility data.

Threat is aggro state, not a percentage of the mob's health. No addon can guarantee a mob will keep attacking you during a scripted fixate or aggro reset.

Commands: `/ta opacity 65` (10–100; lower is more transparent), `/ta status` (loaded version, opacity, selected arrow data source), `/ta size 80` (24–160), `/ta offset 30` (0–150), `/ta on`, `/ta off`, `/ta reset`. Size, offset and opacity persist across reloads. On/off is temporary. Defaults: size 64, offset 20, opacity 65%. Red warnings are intentional for tanking; hide the addon with `/ta off` when playing a damage/healer role.

Display only. Never changes targets, casts, or sends game input. Logic is mock-tested; actual placement and threat reporting need confirmation in the Forever client.


## Threat Watch panel and warnings (1.4)

An orange pulsing glow and LOSING label mark insecure tanking (status 2). A red pulsing glow and LOST label mark mobs with a known threat table that you are not tanking. Unknown threat does not produce a lost-aggro warning. Selected arrows keep their separate vertical bounce.

Threat Watch shows your percentage against every engaged hostile NPC with a visible nameplate. It cannot enumerate enemies outside the client's nameplate visibility/range. Mobs disappear from the list when dead, no longer engaged, or their nameplate vanishes. Identical names have nameplate numbers to distinguish them. These numbers are temporary identifiers, not raid marks.

The selected engaged mob is pinned first, with a gold row, >> prefix and TARGET label. Selecting another mob returns the list to its first page. Ten rows show at a time; mouse wheel over the panel to view the rest. Drag the panel to move it; its position persists. `/ta panel hide` and `/ta panel show` control visibility. `/ta reset` also resets the panel position. The panel is display-only and cannot target mobs on click.

Percentages use the same source and formatting as the arrows, including direct UI formatting of restricted numbers. Colors still use available aggro states where numerical calculations are restricted. Automated mocks cover warnings, scrolling and selected-row behavior; final appearance needs a check inside Forever.


## Adjustable translucent panel (1.5)

The panel defaults to 35% background opacity; text stays readable. Its header has an Opacity slider and Lock/Unlock button. Drag any unused panel area while unlocked to move it. Drag the // grip at the bottom right to resize (320–700 wide, 132–700 high). Rows fit the chosen height and scroll when needed; names fit the chosen width. Lock prevents moving/resizing and hides the grip; scrolling and opacity adjustment still work. Position, dimensions, lock state, background opacity and panel visibility persist across reloads. Selected gold highlighting remains visible even with a transparent background.

Commands: `/ta panel lock`, `/ta panel unlock`, `/ta panel opacity 35`. `/ta reset` restores default position, dimensions, transparency and unlocked state. This panel opacity is independent of `/ta opacity`, which controls the arrows. Size controls work on the display-only frame; no targeting actions are added.


## Compact WoW styling and addon settings (1.6)

The meter has a small 10-point Friz Quadrata title, a Blizzard dialog-header texture, compact 18-pixel rows with outlined text and gold selected-target accents. The subtitle is removed. Movement, resizing and locking remain on the meter. The opacity slider has moved to Options > AddOns > Threat Arrows; `/ta options` opens that page. Opacity changes apply immediately, persist across reloads and do not fade row text. `/ta panel opacity 35` still works. Modern Settings registration is preferred, with a legacy Interface Options fallback. The panel is not installed until requested.

The meter header uses a gold padlock icon: closed when locked, open when unlocked. Hover for a Lock/Unlock tooltip; click to toggle.

## Tiny Threat-style header (1.6.2)

A flat 18-pixel dark title bar replaces the stretched dialog-header artwork. Small white Arial Narrow title text, a 16-pixel shield icon, gray padlock and subtle resize grip match the compact meter style. Rows are 16 pixels high with 1-pixel spacing. The empty panel has no large status message. The panel opacity stays in addon options.

## Hover-only window background (1.6.3)

A shield icon sits at the left of the small title bar. The unused body of the meter is completely transparent when the mouse is outside the window. Hovering shows the background at the opacity selected in addon settings, plus the resize grip (when unlocked) and small count footer. The dark title strip, mob rows, selected-target highlight and percentage text remain visible.

The selected Threat Watch row gently pulses gold on a 1.4-second cycle (background opacity 38–62%). Text and percentage do not fade. The pulse follows target changes; other rows retain their threat tint.

## Selected-row emphasis (1.6.5)

The selected row now pulses bright green instead of gold. A steady, opaque lime-green 2-pixel border surrounds all four edges, so selection stays obvious at the dimmest point of the pulse. Text and percentages stay steady. The border follows selection and is hidden on other rows; the row color is a selection cue, independent of threat state.

## Percentage-filled rows (1.7)

Threat Watch rows are native horizontal status bars, filling left to right from 0 to 100%. The same percentage feeds both text and fill; values above 100 remain visible in text while the native bar caps at full. Restricted percentages go directly to StatusBar:SetValue without Lua arithmetic. Unknown values clear the fill instead of retaining stale data. The selected fill pulses green with the steady lime border; other fills use the threat tint.

Selected rows now have a steady, fully opaque 3-pixel hot-magenta border (1.7.1), contrasting strongly with the pulsing green threat fill.

Selected-row styling (1.7.2): a thin icy-white 1-pixel outline and cyan left accent replace the thick magenta frame. The green percentage fill still pulses and text remains steady.

A small down-arrow icon next to the padlock toggles all overhead arrow displays (including their warning glows/labels), independently of the Threat Watch list. Cyan means on; dim gray means hidden. Hover for a Show/Hide tooltip. The choice persists across reloads; /ta reset restores arrows.

Compact resizing (1.7.4): minimum size is 180 by 60 UI units. Below 280 wide, the separate TARGET/LOSING/LOST column hides to leave room for mob names and percentages. Selection outline, cyan accent and pulse remain visible. A 60-high window fits one row and can scroll through the remaining mobs. Unlock the padlock and drag the bottom-right grip inward.

Tiny Threat-style bottom controls (1.7.5): gray native WoW chat resize-grabber textures in both bottom corners (left mirrored), with a subtle lock/unlock label beside the right grip. Both grips resize from their corresponding corner and persist the window size and position. Bottom controls appear on hover; grips hide while locked. Header padlock remains available.

The header arrow toggle is bright green when enabled and dim gray when disabled (1.7.6). Its centered 9-pixel-wide arrowhead and 3-pixel shaft use integer-aligned geometry for a crisper small icon; the click target remains 18 by 18.

Stable target switching (1.7.7): target changes no longer pin a mob first or reset scrolling. Rows stay in nameplate-number order; only the TARGET label, prefix, pulse and outline follow selection. Entries still appear/disappear as mobs enter/leave nameplate range or combat.

Selected fill contrast (1.7.8): selected rows pulse vivid blue instead of green, distinguishing selection from green threat bars. The icy-white outline, cyan accent, steady text and percentage-based fill width remain.

Health mini-bars (1.8): each row includes a slim 42-by-5 mob-health bar immediately left of threat percentage, green for the selected mob and blue otherwise. Health and threat are independent. Unknown health hides the mini-bar. Selected rows use mirrored icy-blue chevrons at both ends instead of the text >> prefix. Existing blue selection pulse and thin outline remain.

Health styling (1.8.1): native WoW status-bar texture, bronze 1-pixel frame, subtle top sheen and small gold healing-cross badge. Readable health values smoothly color from green at full health through yellow at half health to red near zero. Restricted health still feeds the native bar, with neutral gray when color arithmetic is unavailable. Health coloring is independent of selection.

Selected edge arrows (1.8.2): solid inward-pointing arrows replace thin chevrons. Each has a dark outline, thick shaft and shaded broad head, matching the overhead-arrow design in icy blue. Name and percentage anchors leave room at both edges.

Data fixes (1.8.3): confirmed tanking status 2/3 takes precedence over raw threat (which can report invalid 255% for a tank). Health bars prefer UnitHealthPercent on a fixed 0–1 native range and evaluate a native color curve for restricted percentages; numeric health/max remain a compatibility fallback. Actual Forever combat display still needs verification.

Judgement range (1.8.4): a small J before each mob name is green when Judgement can reach it and red when out of range. A gray ? means unknown, unavailable spell or restricted data. At normal widths, OUT replaces the status label when out of range. At compact widths the colored J remains. This checks the spell itself (not estimated distance), using the spell name with ID 20271 fallback, without casting or changing targets. It does not test mana, cooldown or line of sight.

Health visibility fix (1.8.5): fill updates and optional gradient coloring are isolated. Unsupported or failed color curves leave a neutral visible bar rather than hiding valid health. Errors in normalized health percentage fall back to native health/max values. Supports both EvaluateUnpacked and Evaluate/GetRGBA curve methods.

Threat transitions (1.8.6): use Details' 8-bit percentage color ramp, oriented green at 100% own threat and red at 0%. When tanking and rival party/raid threat is readable, use Tiny Threat's tank formula: red=highest rival percent/100, green=abs(highest rival percent-100)/100, blue=0. Restricted rivals retain the available own-percentage/state fallback. Selection now pulses opacity while retaining threat color; its outline and edge arrows identify selection.

Selection exception (1.8.7): the selected row keeps its blue pulsing fill independently of threat color. The gradual threat palette applies only to non-selected row fills. Health bars/cross badges, Judgement range markers, inward selection arrows, outline and native percentage widths remain.

Restricted health color fix (1.8.8): evaluate the color curve through UnitHealthPercent(unit,false,curve), passing the resulting color directly to the bar. Generic curve evaluation remains a fallback. This avoids generic evaluation failures on restricted health fractions while keeping native fill visible.

Range warning typography (1.8.9): normal-width rows show OUT OF RANGE in red Friz Quadrata with a thick dark outline and shadow. Extra name-column space is reserved for the longer label. Compact rows retain the red J range marker.

Unified typography (1.9.0): mob names, status labels and threat percentages use Friz Quadrata with consistent dark outlines and soft shadows. Names are warm ivory, selected names pale gold, percentages gold; out-of-range warnings retain red. Compact header dimensions, health styling and selection animations remain.


## Artistic styles and custom colors (2.0)

Open `/ta options` (Options > AddOns > Threat Arrows). Click a preview to choose Forged, Arcane, Sentinel or Wisp. Sentinel is the default. Each uses a smooth, high-resolution texture instead of one-pixel strips. As of 2.1, percentages appear only in Threat Watch; arrows are text-free.

The color-mode button switches between the original percentage gradient and custom threat-state colors. In custom mode, secure, losing, lost and unknown each have an independent color. Click a swatch to open the color picker, or enter six hexadecimal digits and press Enter. Escape discards an unfinished hex edit; canceling the picker restores the prior color and mode. Edited colors enable custom mode. Known threat states determine custom colors even when a displayed percentage is restricted; unknown threat stays unknown. Warning text/glows use the losing/lost colors. Nonselected Threat Watch rows use the custom arrow colors; selected-row highlighting and health colors retain their own meanings.

Changes apply immediately and persist through reloads. Reset arrow appearance restores Sentinel and the original palette/gradient without touching size, opacity, calibration or panel layout. To install the artwork, close WoW and rerun Install-ThreatArrows.cmd after the healing app receives the update at Start-All.cmd startup.

## Clean arrows and minimap launcher (2.1)

Percentages are removed from overhead arrows and settings previews. Threat Watch still shows numerical percentages, and threat-based colors continue using the same data.

The shield icon beside the minimap opens appearance settings on left-click. Right-click shows or hides Threat Watch. Drag the icon around the minimap to reposition it; its position is saved across reloads. Hover for the controls. `/ta options` remains available.

## Circular color picker (2.2)

Click any threat-state color swatch to open the color circle. Drag around the circle for hue and toward its center for lower saturation. Use the brightness slider to darken the color. The selected arrow style and live threat indicators preview changes immediately. Done keeps the color; Cancel, Escape, closing settings or switching to another state's swatch restores an unfinished edit. Opening the picker alone does not change the current color mode. Editing enables custom state colors. Hex entry is also available.

## Adjustable range warning (2.3)

Open the minimap icon's settings or `/ta options` and set **Max taunt distance** from 1–40 yards. Default: **10 yards**. Changes apply immediately and persist across reloads. The Threat Watch range marker is now T: green inside the configured distance, red outside (with OUT OF RANGE), or ? when range is unavailable. This is a display warning only.

Validated public client distance is compared with the configured threshold, including the boundary. If distance is unavailable, a Judgement spell check is used only when its reported minimum/maximum range actually proves the configured threshold. A shorter spell being out of range cannot prove a mob is beyond a longer chosen distance; a longer spell being in range cannot prove a mob is within a shorter distance. Such cases, restricted values and unsupported APIs show unknown rather than a guessed result. Settings defaults restore 10 yards; resetting arrow appearance alone preserves the chosen distance.
