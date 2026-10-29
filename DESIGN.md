# DhanyTV interface direction

## Product goal
Help viewers discover a live channel quickly, browse what is airing now and next, and start playback with a remote or touch.

## Visual language
- Midnight background `#080B12`, slate surface `#111722`, elevated slate `#192230`.
- DhanyTV teal `#00D4AA` marks selected navigation, primary actions, and live status.
- High-contrast white titles; secondary metadata uses `#A9B2BF`.
- Rounded channel cards with large station marks and restrained borders.
- Use 8px spacing increments; larger section breaks use 24px/32px.

## Information architecture
- **Live**: search, category filters, favorites, channel grid.
- **Guide**: channel, current program/progress, and next program.
- **Favorites**: saved channels and direct playback.
- Wide landscape layouts use a labeled navigation rail and D-pad focus states. Compact layouts use a bottom navigation bar and touch-sized controls.

## Interaction behavior
- Channel cards open playback on select/tap. Focused TV cards receive a clear outline and subtle scale feedback.
- Guide rows provide an explicit play action and show a schedule-unavailable state when XMLTV has no matching program.
- Loading, empty, and error states keep a visible retry or navigation path.
- EPG data is parsed away from the UI isolate and displayed in the device's local time zone.

## Accessibility and resilience
- All primary actions remain at least 48dp targets.
- Focus and selection use both shape/weight and color.
- Long channel/program names wrap or ellipsize without covering actions; missing logos use a station icon.
- Broken stream sources show an actionable player error; source availability can change upstream.

## Stitch status
The Stitch MCP integration is unavailable in this workspace. This local design spec captures the approved implementation direction and can be uploaded to Stitch after the integration is connected.
