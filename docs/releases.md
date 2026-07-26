# Signed releases

The first complete native set is
[`camel-linux-sm-t970-v5`](https://github.com/adavidtutt/camel-sm-t970/releases/tag/camel-linux-sm-t970-v5).
It is paired with native kernel release
[`camel-kernel-sm-t970-v1`](https://github.com/adavidtutt/camel-sm-t970/releases/tag/camel-kernel-sm-t970-v1).

Fetch and verify the complete set from a fresh Termux checkout:

```sh
pkg install git openssl-tool curl zstd unzip
git clone https://github.com/adavidtutt/camel-sm-t970.git
cd camel-sm-t970
scripts/fetch-linux-release.sh v5 /path/on/sd/camel-v5
```

The fetcher verifies the signed download manifest before trusting assets,
then verifies every SHA-256, the canonical A/B manifest signature, the zstd
frame, the AVB-sized recovery image, and the embedded installer archive.
The trusted Ed25519 public-key DER fingerprint is:

```text
f672cebd8c7384462e71cb170b87f81d5c23202bb2f82ff646b42b03428b89ad
```

The important uncompressed payload hashes are:

```text
rootfs-a.ext4
622eab2e71b0f69682248c6acc440c22f5a647d8aa554d6bb7cf363fcf6ce312

camel-recovery-v5.img
4de8d98755dd2990baa20c9710d8180774e926e70aae2cb5621748a1820e1cfc
```

Decompress the rootfs without changing the signed source:

```sh
zstd -d --sparse rootfs-a.ext4.zst -o rootfs-a.ext4
sha256sum -c rootfs-a.ext4.sha256
```

The raw image is exactly 8 GiB. Keep the compressed source, signatures,
stock recovery, and the last verified working rootfs on both phone and
microSD. Publication is not authorization to flash: v5 remains behind the
v3 installer-log and installed-partition readback gate in
[recovery.md](recovery.md).
