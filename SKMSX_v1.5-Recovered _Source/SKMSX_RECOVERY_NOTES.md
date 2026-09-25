# SKMSX recovery notes

Recovered from `skmsx.com`, extracted from the PMarc archive `skmsx.pma`.

Files:

- `skmsx_recovered.asm` - commented sjasmplus source.
- `skmsx_documented.asm` - documented recovery with the readable, updated
- `skmsx.com` - rebuilt binary from the recovered source.
  SKMSX 2.0 splash; its rebuilt binary is `skmsx_documented_rebuilt.com`.

Build:

```sh
sjasmplus skmsx_recovered.asm
```

Verification:

```text
SHA-256 original: 80e92b3805622cbcdb8c9e2358525e21cebd03d36a3f9ccc9b2d31156c6bd42e
SHA-256 rebuilt : 80e92b3805622cbcdb8c9e2358525e21cebd03d36a3f9ccc9b2d31156c6bd42e
```

The recovered source is byte-identical with the surviving original when assembled
with sjasmplus.  The resident editor is phased to its runtime address at `8000h`;
the installer/hotkey loader remains at its MSX-DOS `.COM` load address, `0100h`.

The documented variant keeps the original code and file size but intentionally
uses the newer 2.0 banner. Its rebuilt COM differs from the 1993 original only
within those banner bytes. The exact original banner is retained in
`../Original/skmsx_original.asm`.

Some routine names are inferred from behavior.  Labels that still look mechanical
mark internal branch points or data references where the original symbolic name is
not recoverable from the binary alone.
