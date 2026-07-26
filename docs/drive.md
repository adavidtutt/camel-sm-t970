# Google Drive without Google Play Services

CAMEL accesses Drive through rclone's Google Drive API backend. No Play
Store, Play Services, Android account daemon, or continuously running Google
process is required.

The OAuth configuration contains a refresh token. It belongs only at:

```text
/home/camel/.config/rclone/rclone.conf
```

It must never be committed to Git or copied into a public release image.

## Configure

From the CAMEL shell:

```sh
camel-drive configure
```

Create a Google Drive remote named `drive`. Rclone prints a URL for browser
authorization, so the consent step can be completed on the phone when CAMEL
itself has no working browser.

## Explicit synchronization

The lowest-memory workflow runs no daemon:

```sh
camel-drive pull
# work in ~/Drive
camel-drive push
```

Both directions use `sync`, so the source side is authoritative and deletions
propagate. Use `rclone copy` manually when a non-deleting transfer is wanted.

## On-demand mount

For live filesystem access:

```sh
camel-drive mount
```

Unmount with:

```sh
camel-drive unmount
```

An optional `camel-drive.service` provides the same mount after networking.
It remains completely dormant unless both the OAuth configuration and
`/etc/camel/enable-drive` exist. Google Android packages should be removed
only after pull, offline editing, push, token backup, and token restoration
have all passed on the tablet.
