# Loam releases

The Mac app's releases and its update feed. Install Loam (macOS 26, Apple silicon):

```bash
curl -fsSL https://raw.githubusercontent.com/Azilone/loam-releases/main/install.sh | bash
```

- `install.sh`: downloads the latest release, checks its SHA-256, installs Loam.app and the `loam` command line.
- `stable.json`, `beta.json`: the update feed. Installed apps read it once a day; every release is signed with
  Ed25519 and checked against the key built into the app.
- The zips are attached to each [release](https://github.com/Azilone/loam-releases/releases).
