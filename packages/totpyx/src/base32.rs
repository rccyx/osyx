// rfc 4648 base32 decoding: https://www.rfc-editor.org/rfc/rfc4648#section-6
// alphabet: a-z2-7 (accepts either case), optional '=' padding at the end.

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DecodeError {
    InvalidChar(u8),
    InvalidLength,
    InvalidPadding,
    NonZeroPaddingBits,
}

impl core::fmt::Display for DecodeError {
    fn fmt(
        &self,
        f: &mut core::fmt::Formatter<'_>,
    ) -> core::fmt::Result {
        match self {
            DecodeError::InvalidChar(b) => {
                write!(f, "invalid base32 character: 0x{b:02x}")
            }
            DecodeError::InvalidLength => {
                write!(f, "invalid base32 length")
            }
            DecodeError::InvalidPadding => {
                write!(f, "invalid base32 padding")
            }
            DecodeError::NonZeroPaddingBits => {
                write!(f, "non-zero padding bits")
            }
        }
    }
}

fn base32_value(b: u8) -> Option<u8> {
    match b {
        b'A'..=b'Z' => Some(b - b'A'),
        b'a'..=b'z' => Some(b - b'a'),
        b'2'..=b'7' => Some(26 + (b - b'2')),
        _ => None,
    }
}

pub fn decode(input: &str) -> Result<Vec<u8>, DecodeError> {
    let bytes = input.as_bytes();
    if bytes.is_empty() {
        return Ok(Vec::new());
    }

    // find padding start (if any) and validate characters.
    let mut pad_start: Option<usize> = None;
    for (i, &b) in bytes.iter().enumerate() {
        if b == b'=' {
            pad_start = Some(i);
            break;
        }
        if base32_value(b).is_none() {
            return Err(DecodeError::InvalidChar(b));
        }
    }

    let unpadded_len = match pad_start {
        None => {
            // unpadded: length mod 8 must not be 1,3,6.
            match bytes.len() % 8 {
                1 | 3 | 6 => return Err(DecodeError::InvalidLength),
                _ => bytes.len(),
            }
        }
        Some(ps) => {
            // padded: rest must be '=' and total length must be multiple of 8.
            if bytes[ps..].iter().any(|&b| b != b'=') {
                return Err(DecodeError::InvalidPadding);
            }
            if bytes.len() % 8 != 0 {
                return Err(DecodeError::InvalidLength);
            }

            let pad_len = bytes.len() - ps;
            let rem = ps % 8;
            let expected_pad = match rem {
                0 => 0,
                2 => 6,
                4 => 4,
                5 => 3,
                7 => 1,
                _ => return Err(DecodeError::InvalidPadding),
            };
            if pad_len != expected_pad {
                return Err(DecodeError::InvalidPadding);
            }

            ps
        }
    };

    let mut out = Vec::with_capacity((unpadded_len * 5 + 7) / 8);

    let mut bits: u32 = 0;
    let mut bit_count: u8 = 0;

    for &b in bytes.iter().take(unpadded_len) {
        let v = base32_value(b).ok_or(DecodeError::InvalidChar(b))?
            as u32;
        bits = (bits << 5) | v;
        bit_count = bit_count.saturating_add(5);

        while bit_count >= 8 {
            bit_count -= 8;
            out.push(((bits >> bit_count) & 0xFF) as u8);
            bits &= (1u32 << bit_count).wrapping_sub(1);
        }
    }

    // any leftover bits must be zero (they are padding bits).
    if bit_count != 0 && bits != 0 {
        return Err(DecodeError::NonZeroPaddingBits);
    }

    Ok(out)
}
