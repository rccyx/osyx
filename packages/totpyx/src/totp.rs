use crate::crypto::{self, HashAlgo};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TotpError {
    InvalidPeriod,
    UnixTimeBeforeT0,
    InvalidDigits,
    DigestTooShort,
    TruncationOutOfRange,
}

impl core::fmt::Display for TotpError {
    fn fmt(
        &self,
        f: &mut core::fmt::Formatter<'_>,
    ) -> core::fmt::Result {
        match self {
            TotpError::InvalidPeriod => {
                write!(f, "invalid period (X must be > 0)")
            }
            TotpError::UnixTimeBeforeT0 => {
                write!(f, "unix time is before T0")
            }
            TotpError::InvalidDigits => {
                write!(f, "invalid digits (must be 6, 7, or 8)")
            }
            TotpError::DigestTooShort => {
                write!(f, "digest too short for dynamic truncation")
            }
            TotpError::TruncationOutOfRange => {
                write!(f, "dynamic truncation out of range")
            }
        }
    }
}

// dynamic truncation (rfc 4226 §5.3): https://www.rfc-editor.org/rfc/rfc4226#section-5.3
// this implementation generalizes to any digest length >= 20 bytes by taking the offset nibble from
// the last byte (the rfc 4226 sha-1 case uses byte 19).
pub fn dynamic_truncate(digest: &[u8]) -> Result<u32, TotpError> {
    if digest.len() < 20 {
        return Err(TotpError::DigestTooShort);
    }
    let offset = (digest[digest.len() - 1] & 0x0F) as usize;
    if offset + 4 > digest.len() {
        return Err(TotpError::TruncationOutOfRange);
    }

    let p = &digest[offset..offset + 4];
    let binary = ((p[0] & 0x7F) as u32) << 24
        | (p[1] as u32) << 16
        | (p[2] as u32) << 8
        | (p[3] as u32);

    Ok(binary)
}

// totp = hotp(k, t) where t = (unix_time - t0) / x (rfc 6238 §4): https://www.rfc-editor.org/rfc/rfc6238#section-4
pub fn generate_totp(
    secret: &[u8],
    unix_time: u64,
    period: u64,
    t0: u64,
    digits: usize,
    algo: HashAlgo,
) -> Result<String, TotpError> {
    if period == 0 {
        return Err(TotpError::InvalidPeriod);
    }
    if unix_time < t0 {
        return Err(TotpError::UnixTimeBeforeT0);
    }
    // rfc 4226 requires at least 6 digits and permits 7 or 8 (see §5.4): https://www.rfc-editor.org/rfc/rfc4226#section-5.4
    if !(digits == 6 || digits == 7 || digits == 8) {
        return Err(TotpError::InvalidDigits);
    }

    let counter = (unix_time - t0) / period;
    let counter_bytes = counter.to_be_bytes();

    let digest = crypto::hmac(algo, secret, &counter_bytes);
    let binary = dynamic_truncate(&digest)?;

    let modulo = match digits {
        6 => 1_000_000u32,
        7 => 10_000_000u32,
        8 => 100_000_000u32,
        _ => return Err(TotpError::InvalidDigits),
    };

    let otp = binary % modulo;
    Ok(format!("{:0width$}", otp, width = digits))
}

#[cfg(test)]
mod tests {
    use super::*;

    // rfc 6238 appendix b test vectors: https://www.rfc-editor.org/rfc/rfc6238#appendix-B
    #[test]
    fn rfc6238_vectors_sha1_sha256_sha512() {
        let times: [u64; 6] = [
            59,
            1_111_111_109,
            1_111_111_111,
            1_234_567_890,
            2_000_000_000,
            20_000_000_000,
        ];

        let seed_sha1 = b"12345678901234567890".to_vec();
        let seed_sha256 =
            b"12345678901234567890123456789012".to_vec();
        let seed_sha512 =
            b"1234567890123456789012345678901234567890123456789012345678901234".to_vec();

        let expected_sha1 = [
            "94287082", "07081804", "14050471", "89005924",
            "69279037", "65353130",
        ];
        let expected_sha256 = [
            "46119246", "68084774", "67062674", "91819424",
            "90698825", "77737706",
        ];
        let expected_sha512 = [
            "90693936", "25091201", "99943326", "93441116",
            "38618901", "47863826",
        ];

        for (i, &t) in times.iter().enumerate() {
            let got = generate_totp(
                &seed_sha1,
                t,
                30,
                0,
                8,
                HashAlgo::Sha1,
            )
            .unwrap();
            assert_eq!(got, expected_sha1[i]);

            let got = generate_totp(
                &seed_sha256,
                t,
                30,
                0,
                8,
                HashAlgo::Sha256,
            )
            .unwrap();
            assert_eq!(got, expected_sha256[i]);

            let got = generate_totp(
                &seed_sha512,
                t,
                30,
                0,
                8,
                HashAlgo::Sha512,
            )
            .unwrap();
            assert_eq!(got, expected_sha512[i]);
        }
    }
}
