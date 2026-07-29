# Sign-in and build safety

YTMinimum does not implement a login screen and does not receive a Google
username or password. Sign-in remains YouTube's built-in Google SSO flow.

The sideloading compatibility layer in `Sources/YTMSideloading.xm`:

- reports YouTube's official app name and bundle identifier to YouTube's own
  sign-in components;
- creates an empty `YTMinimum.BundleSeedID` keychain marker solely to discover
  the access group granted by the app's SideStore signature;
- directs YouTube's SSO helpers to that permitted access group; and
- redirects unavailable App Group storage into this app's private Documents
  container.

It does not query Google keychain records, inspect cookies or OAuth tokens,
install a network client, or send account information to a YTMinimum server.
YTMinimum has no server.

## Reviewed trust boundaries

The tweak source and compiled dylib should not be the only things considered:

1. **Input IPA:** Use a decrypted YouTube 21.30.5 IPA obtained from a source you
   trust. YTMinimum cannot prove that an externally supplied IPA was not
   modified before the workflow downloaded it.
2. **IPA hash:** Supply `ipa_sha256` when running the workflow. The workflow
   will stop if the downloaded file no longer matches that hash.
3. **Build dependencies:** Theos, the iOS SDK, Cyan, and every GitHub Action are
   pinned to immutable commits in `.github/workflows/main.yml`.
4. **Sideloading:** Install the finished IPA through the official SideStore
   project you already trust. Do not provide Apple or Google credentials to an
   unrelated signing website.

## First sign-in check

After installing a fresh build, the account chooser should be YouTube's normal
Google sign-in interface. YTMinimum does not display its own credential form.
If a page asks for a password outside Google's normal interface, close it and
do not continue.

No source review can guarantee the safety of an unknown third-party IPA. With a
trusted input IPA, the pinned workflow, and the reviewed YTMinimum source, no
credential collection or exfiltration behavior is present in this project.

## Google account policy risk

Credential safety and account-policy safety are different. YTMinimum modifies
YouTube and can remove advertising. [YouTube's Terms](https://www.youtube.com/static?template=terms)
restrict modifying or interfering with the service, and YouTube reserves the
right to restrict or terminate access for material or repeated breaches. This
project cannot guarantee that Google will permit a modified client indefinitely.
Use a secondary Google account for initial testing if losing access to a
primary channel would be unacceptable.
