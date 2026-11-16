# totpyx

A tiny, dependency-free TOTP generator (RFC 6238) with a strict RFC 4648 Base32 decoder.

Provides a fully auditable TOTP implementation with no third-party crypto dependencies, no hidden behavior, and a deliberately minimal attack and trust surface.

- **TOTP (RFC 6238)** generator
- **HMAC algorithms:** SHA-1, SHA-256, SHA-512
- **Digits:** 6, 7, or 8
- **Period (X):** configurable (default 30 seconds)
- **T0:** configurable (default 0)
- **Time override:** supply an explicit Unix timestamp to reproduce test vectors or debug clock drift
- **Base32 decoding:** RFC 4648 alphabet (`A–Z2–7`), case-insensitive, optional `=` padding

## Install

As a CLI:

```bash
cargo install totpyx
```

As a library:

```bash
cargo add totpyx
```

## CLI usage

```bash
totpyx <base32-secret> \
  [--algo sha1|sha256|sha512] \
  [--digits 6|7|8] \
  [--period <seconds>] \
  [--t0 <unix>] \
  [--time <unix>]
```

### Examples

Generate a standard 6-digit TOTP (SHA-1, 30s period, T0=0):

```bash
totpyx JBSWY3DPEHPK3PXP
```

Generate SHA-256 with 8 digits:

```bash
totpyx JBSWY3DPEHPK3PXP --algo sha256 --digits 8
```

Generate with a custom period:

```bash
totpyx JBSWY3DPEHPK3PXP --period 60
```

Reproduce a code for a specific Unix timestamp (debugging drift, server-side validation):

```bash
totpyx JBSWY3DPEHPK3PXP --time 1710000000
```

### Notes on secrets

- If your issuer provides a Base32 secret with spaces or hyphens, remove them first.
- Padding `=` at the end is allowed but not required.
- Invalid lengths or padding are rejected firsthand.

## Library usage

Minimal example:

```rust
use totpyx::crypto::HashAlgo;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let secret = totpyx::base32::decode("JBSWY3DPEHPK3PXP")?;

    let unix_time = 1_710_000_000u64;

    let code = totpyx::totp::generate_totp(
        &secret,
        unix_time,
        30,        // period (X)
        0,         // T0
        6,         // digits
        HashAlgo::Sha1,
    )?;

    println!("{code}");
    Ok(())
}
```

## License

Apache-2.0 © [@rccyx](https://rccyx.com)
