# Changelog

All notable changes to the **KambingTV** project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2026-10-29

### 🚀 Rebranding & Identity
* Rebranded application from DhanyTV to **KambingTV**.
* Generated minimalist geometric logo emblem combining a TV monitor, antenna horns, and glowing cyan play indicator.
* Installed high-resolution Android launcher mipmap icons across all densities (`mdpi`, `hdpi`, `xhdpi`, `xxhdpi`, `xxxhdpi`).
* Renamed application manifest attributes, title bars, and native foreground playback notification channels.

### 📺 Multi-Protocol Screencasting (`dart_cast`)
* Added native screencasting support for **Google TV**, **Chromecast (CASTV2)**, **Smart TVs (DLNA/UPnP)**, and **AirPlay** via `dart_cast` (v0.7.4).
* Built-in local HTTP proxy transparently forwards custom IPTV stream headers (`User-Agent`, `Referer`, auth cookies) before serving manifests to Google Cast receivers, eliminating HTTP 403 Forbidden errors on protected feeds.
* Created [`CastDeviceSheet`](lib/widgets/cast_device_sheet.dart) modal bottom sheet with real-time Wi-Fi device scanning and protocol badges.
* Integrated Cast button in [`PlayerScreen`](lib/screens/player_screen.dart) with connection state tracking (`Icons.cast` ↔ `Icons.cast_connected`), auto-pause for local playback, and remote TV controls.
* Added `CHANGE_WIFI_MULTICAST_STATE` and network state permissions in [`AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml) for mDNS and SSDP discovery.

### ⚡ Slow Connection & Low-Bandwidth Optimizations
* Implemented 1-tap **Slow Connection Mode** (`Icons.speed`) capping video stream bitrate to **800 kbps** via native ExoPlayer track selection parameters, ensuring smooth 360p/480p playback on weak mobile signals.
* Configured [`ThaPlaybackOptions`](lib/services/playback_settings_service.dart) with infinite auto-retry (`maxRetryCount: -1`) and exponential backoff (`500ms` to `4s`) to seamlessly survive packet drops and mobile cell handoffs.
* Added smart recovery overlay to [`PlayerScreen`](lib/screens/player_screen.dart) offering 1-tap remedies ("Slow Connection Mode", "Audio-Only", "Retry") when a stream stalls.
* Persisted Slow Connection preference across sessions via `SharedPreferences`.

### 📅 Multi-Country XMLTV EPG (TV Guide)
* Integrated 60-country XMLTV EPG feed directory from `ge.m3uiptv.com` (hosted at `https://epg.lat/files/{code}.xml.gz`).
* Added transparent GZIP decompression (`decodeResponseBody()`) for `.xml.gz` payloads.
* Implemented concurrent multi-source schedule fetching, time zone normalization, and schedule matching with `@SD`/`@HD` resolution tag stripping.

### 🔍 Category Organization & Filter UI/UX
* Developed [`CategoryService`](lib/services/category_service.dart) aggregating 208 raw M3U playlist groups into 10 unified genres and 169 countries with ISO flag emojis and live channel counts.
* Created [`CategorySelectorSheet`](lib/widgets/category_selector_sheet.dart) modal bottom sheet with live search, real-time counts, and tabbed browsing (`Genres`, `Countries`, `All Groups`).
* Added horizontal quick-filter carousels to [`HomeScreen`](lib/screens/home_screen.dart) and [`GuideScreen`](lib/screens/guide_screen.dart).

### 🎨 Channel Card Placeholders & Dead Logo Fix
* Designed deterministic 8-palette dark gradient cards ([`ChannelAvatar`](lib/widgets/channel_avatar.dart)) based on channel name hashes with embedded ISO country flag badges.
* Purged 120 dead Imgur URLs returning HTTP 200 `removed.png` from bundled playlists.
* Added runtime logo validation regex and desktop browser `User-Agent` headers to prevent CDN 403 Forbidden image errors.

### 🎧 Background Audio Playback
* Created native Android foreground service ([`MediaPlaybackService.kt`](android/app/src/main/kotlin/com/opentv/opentv/MediaPlaybackService.kt)) for locked screen / screen-off audio listening.
* Added dedicated in-app Audio-Only mode with background audio card and notification controls.

### 🧹 Quality & Testing
* 25/25 unit and widget tests passing across all test suites.
* 0 warnings and 0 errors in `flutter analyze`.
* Built production AOT release APK ([`build/KambingTV-release.apk`](build/KambingTV-release.apk)) and verified on Android 15 Redroid emulator.
