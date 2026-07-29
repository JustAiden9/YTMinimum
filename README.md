# YTMinimum

YTMinimum is a focused YouTube tweak for personal sideloading. It keeps the
Feed, Player, and Tab bar controls selected from YTLite/YouTube Plus while
leaving unrelated features out.

## Target

- YouTube: **21.30.5** (other 21.x builds load, but are untested)
- iOS runtime: **26.5.2**
- Minimum deployment target: **iOS 16.0**
- Sideloading: **SideStore**

## Features

Every option lives in YouTube's own settings screen under **YTMinimum**, split
into **Feed**, **Player**, **Tab bar**, and **About**.

### Feed

- Remove ads
- Hide Shorts while optionally keeping them in Subscriptions
- Remove horizontal shelves, community posts, mixes, More topics, and Playables
- Remove promo banners
- Fix cover image hosts

Hidden feed items are removed by collapsing the cell that carries them. Options
that rely on YouTube's internal layout names ship **disabled**, because those
names change between YouTube releases; enable them one at a time.

### Player

- Progress bar style and colors
- Default playback rate
- Background playback and forced mini player
- Disable autoplay, skip content warnings, and disable hints
- Automatic fullscreen and exit fullscreen on finish
- Left/right brightness and volume gestures

### Tab bar

- Startup page
- Tab order: enable, disable, and reorder Home, Explore, Create, Subscriptions,
  Library, Shorts, History, Posts, and Watch Later
- Translucent style
- Hide labels and indicators

### About

- Tweak version, target YouTube version, and installed YouTube version
- Reset every option to its default

## Building

Run **Create YTMinimum app** from the repository's Actions tab. Supply a direct
HTTPS download URL to your own decrypted YouTube 21.30.5 IPA. Supplying its
SHA-256 is strongly recommended so the workflow can reject a changed download.
The workflow builds the tweak, injects it with Cyan, and places the finished
IPA in a draft release.

YouTube and decrypted IPA files are not included in this repository.

Use [TESTING.md](TESTING.md) for the first SideStore build and device check.
Read [SECURITY.md](SECURITY.md) before signing in with a Google account.
