# First-device test

1. Push this folder to a GitHub repository.
2. In **Actions**, run **Create YTMinimum app**.
3. Paste the same kind of direct decrypted-IPA URL used by the YTLite workflow.
4. Leave the display name and bundle ID at their defaults for the first build.
5. Download the IPA from the draft release and install it with SideStore.

After YouTube opens:

1. Confirm Google sign-in works.
2. Open YouTube **Settings** and confirm **YTMinimum** appears.
3. Open the Feed, Player, and Tab bar pages.
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

If YouTube crashes, attach the newest YouTube `.ips` file from:

**Settings → Privacy & Security → Analytics & Improvements → Analytics Data**

No Apple Account password or signing credential is needed for debugging.

