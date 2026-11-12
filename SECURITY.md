# Security

## Reporting a vulnerability

Please use GitHub's **Security → Report a vulnerability** flow for anything
sensitive: credential exposure, a TCC or Gatekeeper bypass, arbitrary code
execution, or a malicious response from a configured Beszel hub. Do not open a
public issue for those.

For ordinary bugs, open an issue and include the output of
`islet --diagnose` with server names, addresses and track titles redacted.

## Design notes

- islet has no analytics or telemetry. The only outbound requests are to the
  Beszel hub configured in Settings.
- The Beszel password and Cloudflare Access secret live in
  `~/Library/Application Support/islet/credentials.json` with 0600 permissions.
  A file is used instead of Keychain because every ad-hoc rebuild changes the
  code signature and invalidates Keychain ACLs.
- `--beszel-save` reads `BESZEL_PASSWORD` / `CF_ACCESS_CLIENT_SECRET` from the
  environment or `--beszel-password-stdin`. Passing a secret in argv is
  supported for compatibility but is visible to other local processes.
- Release builds are ad-hoc signed unless a Developer ID certificate is
  supplied. Check the SHA-256 published with the release or in the Homebrew
  cask; build from source if you need a binary you can audit.
- The app is not sandboxed: the MediaRemote helper, Bluetooth control and
  CoreWLAN need direct framework access. It uses private MediaRemote and
  IOBluetooth symbols; that is why it is distributed outside the App Store.

## Supported versions

Only the latest release is supported. Security fixes are released as patch
versions and the Homebrew cask is updated alongside the GitHub release.
