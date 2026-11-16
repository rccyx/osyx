mod base32;
mod crypto;
mod totp;

use std::env;
use std::io::{self, Write};
use std::time::{SystemTime, UNIX_EPOCH};

use crypto::HashAlgo;

fn usage(bin: &str) {
    let _ = writeln!(
        io::stderr(),
        "usage: {bin} <base32-secret> [--algo sha1|sha256|sha512] [--digits 6|7|8] [--period <seconds>] [--t0 <unix>] [--time <unix>]"
    );
}

fn parse_u64(name: &str, s: &str) -> Result<u64, String> {
    s.parse::<u64>().map_err(|_| format!("invalid {name}: {s}"))
}

fn parse_usize(name: &str, s: &str) -> Result<usize, String> {
    s.parse::<usize>()
        .map_err(|_| format!("invalid {name}: {s}"))
}

fn parse_algo(s: &str) -> Result<HashAlgo, String> {
    match s {
        "sha1" => Ok(HashAlgo::Sha1),
        "sha256" => Ok(HashAlgo::Sha256),
        "sha512" => Ok(HashAlgo::Sha512),
        _ => Err(format!("invalid algo: {s}")),
    }
}

#[allow(clippy::print_stdout)]
fn main() {
    let mut secret_b32: Option<String> = None;

    let mut algo = HashAlgo::Sha1;
    let mut digits: usize = 6;
    let mut period: u64 = 30;
    let mut t0: u64 = 0;
    let mut time_override: Option<u64> = None;

    let mut args = env::args();
    let bin = args.next().unwrap_or_else(|| "totpyx".to_string());

    let mut it = args.peekable();
    while let Some(arg) = it.next() {
        match arg.as_str() {
            "--help" | "-h" => {
                usage(&bin);
                return;
            }
            "--algo" => {
                let v = match it.next() {
                    Some(v) => v,
                    None => {
                        usage(&bin);
                        std::process::exit(1);
                    }
                };
                algo = match parse_algo(&v) {
                    Ok(a) => a,
                    Err(e) => {
                        let _ = writeln!(io::stderr(), "{e}");
                        std::process::exit(1);
                    }
                };
            }
            "--digits" => {
                let v = match it.next() {
                    Some(v) => v,
                    None => {
                        usage(&bin);
                        std::process::exit(1);
                    }
                };
                digits = match parse_usize("digits", &v) {
                    Ok(d) => d,
                    Err(e) => {
                        let _ = writeln!(io::stderr(), "{e}");
                        std::process::exit(1);
                    }
                };
            }
            "--period" => {
                let v = match it.next() {
                    Some(v) => v,
                    None => {
                        usage(&bin);
                        std::process::exit(1);
                    }
                };
                period = match parse_u64("period", &v) {
                    Ok(x) => x,
                    Err(e) => {
                        let _ = writeln!(io::stderr(), "{e}");
                        std::process::exit(1);
                    }
                };
            }
            "--t0" => {
                let v = match it.next() {
                    Some(v) => v,
                    None => {
                        usage(&bin);
                        std::process::exit(1);
                    }
                };
                t0 = match parse_u64("t0", &v) {
                    Ok(x) => x,
                    Err(e) => {
                        let _ = writeln!(io::stderr(), "{e}");
                        std::process::exit(1);
                    }
                };
            }
            "--time" => {
                let v = match it.next() {
                    Some(v) => v,
                    None => {
                        usage(&bin);
                        std::process::exit(1);
                    }
                };
                time_override = Some(match parse_u64("time", &v) {
                    Ok(x) => x,
                    Err(e) => {
                        let _ = writeln!(io::stderr(), "{e}");
                        std::process::exit(1);
                    }
                });
            }
            _ if arg.starts_with("--") => {
                let _ = writeln!(io::stderr(), "unknown flag: {arg}");
                usage(&bin);
                std::process::exit(1);
            }
            _ => {
                if secret_b32.is_some() {
                    let _ = writeln!(
                        io::stderr(),
                        "unexpected extra arg: {arg}"
                    );
                    usage(&bin);
                    std::process::exit(1);
                }
                secret_b32 = Some(arg);
            }
        }
    }

    let secret_b32 = match secret_b32 {
        Some(s) => s,
        None => {
            usage(&bin);
            std::process::exit(1);
        }
    };

    let secret = match base32::decode(&secret_b32) {
        Ok(s) => s,
        Err(e) => {
            let _ =
                writeln!(io::stderr(), "base32 decode error: {e}");
            std::process::exit(1);
        }
    };

    let unix_time = match time_override {
        Some(t) => t,
        None => match SystemTime::now().duration_since(UNIX_EPOCH) {
            Ok(d) => d.as_secs(),
            Err(_) => {
                let _ = writeln!(
                    io::stderr(),
                    "system time before unix epoch"
                );
                std::process::exit(1);
            }
        },
    };

    let code = match totp::generate_totp(
        &secret, unix_time, period, t0, digits, algo,
    ) {
        Ok(c) => c,
        Err(e) => {
            let _ =
                writeln!(io::stderr(), "totp generation error: {e}");
            std::process::exit(1);
        }
    };

    println!("{code}");
}
