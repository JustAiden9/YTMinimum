# YTMinimum

YTMinimum is a focused YouTube tweak for personal sideloading. It keeps the
Feed, Player, and Tab bar controls selected from YTLite/YouTube Plus while
leaving unrelated features out.

## Target

- YouTube: **21.30.5**
- iOS runtime: **26.5.2**
- Minimum deployment target: **iOS 16.0**
- Sideloading: **SideStore**

## Features

### Feed

- Remove ads
- Hide Shorts while optionally keeping them in Subscriptions
- Remove More topics, community posts, mixes, live videos, horizontal shelves,
  and Playables
- Fix cover image hosts

### Player

- Progress bar colors
- Default playback rate
- Background playback and forced mini player
- Disable autoplay, skip content warnings, and disable hints
- Automatic fullscreen and exit fullscreen on finish
- Left/right brightness and volume gestures

### Tab bar

- Startup page
- Translucent style
- Hide labels and indicators
- Enable, disable, and reorder Home, Explore, Create, Subscriptions, Library,
  Shorts, History, Posts, and Watch Later

## Building

Run **Create YTMinimum app** from the repository's Actions tab. Supply a direct
download URL to your own decrypted YouTube 21.30.5 IPA. The workflow builds the
tweak, injects it with Cyan, and places the finished IPA in a draft release.

YouTube and decrypted IPA files are not included in this repository.

Use [TESTING.md](TESTING.md) for the first SideStore build and device check.
