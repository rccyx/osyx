use anyhow::{Context, Result};
use std::{
    fs,
    io::{BufRead, BufReader},
    os::unix::fs::PermissionsExt,
    path::PathBuf,
    process::{Child, Command, Output, Stdio},
    sync::atomic::{AtomicUsize, Ordering},
};
use zbus::{
    Connection, ObjectPath, connection::Builder, fdo::ObjectManager,
};

const NETKIT: &str = env!("CARGO_BIN_EXE_netkit");
const DEVICE: &str = "/net/connman/iwd/0/1";
const NETWORK: &str = "/net/connman/iwd/0/1/network";
static NEXT_DIRECTORY: AtomicUsize = AtomicUsize::new(0);

#[test]
fn radio_switches_all_iwd_adapters() -> Result<()> {
    zbus::block_on(async {
        let fixture = Fixture::_new("open").await?;
        for (radio, powered) in [("off", false), ("on", true)] {
            let execution = fixture._invoke(&["wifi", radio]).await?;
            assert!(execution.status.success(), "{execution:?}");
            for path in ["/net/connman/iwd/0", "/net/connman/iwd/1"] {
                let proxy = zbus::Proxy::new(
                    &fixture._connection,
                    "net.connman.iwd",
                    path,
                    "net.connman.iwd.Adapter",
                )
                .await?;
                assert_eq!(
                    proxy.get_property::<bool>("Powered").await?,
                    powered
                );
            }
        }
        Ok(())
    })
}

#[test]
fn qr_shares_connected_open_network_and_honors_interface_selection()
-> Result<()> {
    zbus::block_on(async {
        let fixture = Fixture::_new("open").await?;
        for arguments in [vec!["qr"], vec!["qr", "-i", "wlan0"]] {
            let execution = fixture._invoke(&arguments).await?;
            assert!(execution.status.success(), "{execution:?}");
            let output = String::from_utf8_lossy(&execution.stdout);
            assert!(
                output.contains(
                    "WIFI:T:nopass;S:Cafe\\; Guest;P:;H:false;;"
                ),
                "{output}"
            );
            assert!(output.contains("SSID: \"Cafe; Guest\""));
        }
        Ok(())
    })
}

#[test]
fn qr_rejects_an_unconnected_interface() -> Result<()> {
    zbus::block_on(async {
        let fixture = Fixture::_new("open").await?;
        let execution =
            fixture._invoke(&["qr", "-i", "wlan9"]).await?;
        assert_eq!(execution.status.code(), Some(1));
        assert!(
            String::from_utf8_lossy(&execution.stderr)
                .contains("no connected iwd Wi-Fi station on wlan9")
        );
        assert!(execution.stdout.is_empty());
        Ok(())
    })
}

#[test]
fn qr_rejects_enterprise_credentials() -> Result<()> {
    zbus::block_on(async {
        let fixture = Fixture::_new("8021x").await?;
        let execution = fixture._invoke(&["qr"]).await?;
        assert_eq!(execution.status.code(), Some(1));
        assert!(
            String::from_utf8_lossy(&execution.stderr)
                .contains("does not support iwd security type 8021x")
        );
        assert!(execution.stdout.is_empty());
        Ok(())
    })
}

#[test]
fn unavailable_iwd_is_reported_without_touching_host_services()
-> Result<()> {
    for arguments in
        [vec!["qr"], vec!["wifi", "on"], vec!["wifi", "off"]]
    {
        let execution = Command::new(NETKIT)
            .args(arguments)
            .env(
                "DBUS_SYSTEM_BUS_ADDRESS",
                "unix:path=/nonexistent/netkit-system-bus",
            )
            .output()?;
        assert_eq!(execution.status.code(), Some(1));
        assert!(
            String::from_utf8_lossy(&execution.stderr)
                .contains("could not connect to the system D-Bus")
        );
    }
    Ok(())
}

struct Adapter {
    powered: bool,
}

#[zbus::interface(name = "net.connman.iwd.Adapter")]
impl Adapter {
    #[zbus(property)]
    const fn powered(&self) -> bool {
        self.powered
    }
    #[zbus(property)]
    const fn set_powered(&mut self, value: bool) {
        self.powered = value;
    }
}

struct Device;

#[zbus::interface(name = "net.connman.iwd.Device")]
#[expect(
    clippy::unused_self,
    reason = "D-Bus properties require an instance receiver"
)]
impl Device {
    #[zbus(property)]
    const fn name(&self) -> &'static str {
        "wlan0"
    }
}

struct Station;

#[zbus::interface(name = "net.connman.iwd.Station")]
#[expect(
    clippy::unused_self,
    reason = "D-Bus properties require an instance receiver"
)]
impl Station {
    #[zbus(property)]
    const fn state(&self) -> &'static str {
        "connected"
    }
    #[zbus(property)]
    fn connected_network(
        &self,
    ) -> zbus::fdo::Result<ObjectPath<'static>> {
        ObjectPath::try_from(NETWORK).map_err(|error| {
            zbus::fdo::Error::Failed(error.to_string())
        })
    }
}

struct Network {
    security: String,
}

#[zbus::interface(name = "net.connman.iwd.Network")]
#[expect(
    clippy::unused_self,
    reason = "D-Bus properties require an instance receiver"
)]
impl Network {
    #[zbus(property)]
    const fn name(&self) -> &'static str {
        "Cafe; Guest"
    }
    #[zbus(property)]
    fn r#type(&self) -> &str {
        &self.security
    }
}

struct Fixture {
    _daemon: Child,
    _connection: Connection,
    _address: String,
    _directory: PathBuf,
}

impl Fixture {
    async fn _new(security: &str) -> Result<Self> {
        let mut daemon = Command::new("dbus-daemon")
            .args(["--session", "--nofork", "--print-address=1"])
            .stdout(Stdio::piped())
            .spawn()?;
        let mut address = String::new();
        BufReader::new(
            daemon
                .stdout
                .take()
                .context("D-Bus stdout unavailable")?,
        )
        .read_line(&mut address)?;
        let address = address.trim().to_owned();
        let connection = Builder::address(address.as_str())
            .name("net.connman.iwd")
            .serve_at("/", ObjectManager)
            .serve_at("/net/connman/iwd/0", Adapter { powered: true })
            .serve_at("/net/connman/iwd/1", Adapter { powered: true })
            .serve_at(DEVICE, Device)
            .serve_at(DEVICE, Station)
            .serve_at(
                NETWORK,
                Network {
                    security: security.into(),
                },
            )
            .build()
            .await?;
        let sequence = NEXT_DIRECTORY.fetch_add(1, Ordering::Relaxed);
        let directory = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join(format!(
                "target/iwd-tests/{}-{sequence}",
                std::process::id()
            ));
        fs::create_dir_all(&directory)?;
        let renderer = directory.join("qrencode");
        fs::write(&renderer, "#!/bin/sh\nexec /bin/cat\n")?;
        fs::set_permissions(
            renderer,
            fs::Permissions::from_mode(0o755),
        )?;
        Ok(Self {
            _daemon: daemon,
            _connection: connection,
            _address: address,
            _directory: directory,
        })
    }

    async fn _invoke(&self, arguments: &[&str]) -> Result<Output> {
        let mut command = Command::new(NETKIT);
        command
            .args(arguments)
            .env("DBUS_SYSTEM_BUS_ADDRESS", &self._address)
            .env("PATH", &self._directory)
            .stdin(Stdio::null());
        Ok(zruntime::process::Command::from(command)
            .output(&zruntime::SharedRuntime::current()?)
            .await?)
    }
}

impl Drop for Fixture {
    fn drop(&mut self) {
        assert!(self._daemon.kill().is_ok());
        assert!(self._daemon.wait().is_ok());
        assert!(fs::remove_dir_all(&self._directory).is_ok());
    }
}
