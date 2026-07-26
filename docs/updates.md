# Signed A/B updates

CAMEL's update format uses an Ed25519 signature over a canonical text
manifest. The trusted public key is embedded in the rootfs at:

```text
/usr/share/camel/keys/release-ed25519.pub.pem
```

Its DER SHA-256 fingerprint is:

```text
f672cebd8c7384462e71cb170b87f81d5c23202bb2f82ff646b42b03428b89ad
```

The corresponding private key is not in this repository. It remains on the
owner's phone and must be backed up separately to encrypted offline storage.

## Create a release

```sh
CAMEL_SIGNING_KEY=/secure/path/release-ed25519.pem \
  scripts/create-release-manifest.sh v4 \
  out/rootfs-a.ext4 out/camel-recovery.img
```

The command writes the manifest, its detached signature, and `SHA256SUMS`.
It then verifies its own signature using the repository's public key.
For another canonical manifest such as a kernel `SHA256SUMS`, use:

```sh
scripts/sign-manifest.sh SHA256SUMS
```

That command also verifies the detached signature before returning.

## Stage an inactive rootfs

On CAMEL Linux:

```sh
sudo camel-stage-update \
  camel-v4.manifest camel-v4.manifest.sig rootfs-v4.ext4
```

The staging command:

1. verifies the Ed25519 signature;
2. validates the rootfs byte count and SHA-256;
3. refuses to continue unless the active slot is explicit;
4. writes only the inactive slot through a temporary filename;
5. hashes the staged bytes again;
6. atomically renames the verified image;
7. records a pending slot with three allowed boot attempts.

After the pending rootfs reaches systemd, `camel-boot-commit.service` runs a
separate recovery health gate. SSH, the USB gadget service, and the actual
`172.31.0.1/24` phone-recovery address must all be live before it atomically
makes that slot active and writes `slot-A.success` or `slot-B.success`.

The v3 diagnostic initramfs does not consume A/B state. The candidate v4
implementation is preserved as `initramfs/init-ab` and is now the default
for `scripts/build-recovery.sh`. It selects a pending
slot, decrements its attempt counter before mounting it, validates the whole
rootfs SHA-256, exposes the chosen slot through `/run/camel-slot`, and falls
back to the last committed slot after the attempts are exhausted.

Build the v4 recovery locally with:

```sh
scripts/build-recovery.sh
```
