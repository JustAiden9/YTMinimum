# First-device test

1. Push this folder to a GitHub repository.
2. In **Actions**, run **Create YTMinimum app**.
3. Paste the same kind of direct decrypted-IPA URL used by the YTLite workflow.
4. If available, paste the trusted SHA-256 for that exact IPA into
   **Expected IPA SHA-256**.
5. Leave the display name and bundle ID at their defaults for the first build.
6. Download the IPA from the draft release and install it with SideStore.

After YouTube opens:

1. Confirm Google sign-in uses YouTube's normal Google account chooser. Do not
   enter credentials into an unfamiliar or YTMinimum-branded form.
2. Open YouTube **Settings** and confirm **YTMinimum** appears.
3. Open the Feed, Player, Tab bar, and About pages.
4. Test the default configuration before changing any switches.
5. Change one setting at a time and restart YouTube if a visual change does not
   refresh immediately.

For the first report, note:

- Whether YouTube launches or closes immediately
- Whether YTMinimum appears in Settings
- Whether Home and Subscriptions load
- Whether a normal video starts
- Whether background playback works
- Whether the tab order matches Home, Explore, Create, Subscriptions, Library

## Empty feed check

Home, Subscriptions, You, and the related list under a video must show content
immediately, with no tall empty gap that only fills in after scrolling. If a gap
appears:

1. Open **Settings → YTMinimum → Feed** and turn off every option whose
   description ends with *Depends on YouTube's layout names*.
2. Restart YouTube. If the gap is gone, re-enable those options one at a time to
   find which one leaves the gap.
3. Report the option name and the tab it happened on, because that means the
   layout identifier for that option changed in this YouTube release.

Options that depend on layout names ship disabled for exactly this reason. Only
**Remove ads**, **Hide Shorts**, **Remove promo banners**, and **Fix cover
artwork** are on by default.

If YouTube crashes, attach the newest YouTube `.ips` file from:

**Settings → Privacy & Security → Analytics & Improvements → Analytics Data**

No Apple Account password or signing credential is needed for debugging.
