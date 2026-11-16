use crate::unix;
use anyhow::{Context, Result, ensure};
use clap::{Args, Subcommand};
use std::process::{Command, Stdio};
use zbus::{OwnedObjectPath, fdo::ObjectManagerProxy};

mod sharing;

#[derive(Args)]
pub struct WifiOptions {
    #[command(subcommand)]
    pub command: Option<Radio>,
}

#[derive(Args)]
pub struct WifiInterface {
    /// Wireless interface; select the first connected iwd station by default
    #[arg(short, long)]
    pub interface: Option<String>,
}

#[derive(Subcommand)]
pub enum Radio {
    /// Enable all iwd Wi-Fi adapters
    On,
    /// Disable all iwd Wi-Fi adapters
    Off,
}

pub fn run(options: WifiOptions) -> Result<()> {
    options.command.map_or_else(
        || unix::installed("impala", std::iter::empty::<&str>()),
        |radio| {
            zbus::block_on(_set_radio(matches!(radio, Radio::On)))
        },
    )
}

pub fn share(options: WifiInterface) -> Result<()> {
    let devices = Command::new("nmcli")
        .args(["-t", "-f", "DEVICE,TYPE,STATE", "device", "status"])
        .output();

    if let Ok(output) = devices
        && output.status.success()
    {
        let listing = String::from_utf8(output.stdout)?;

        let active = listing.lines().find_map(|line| {
            let (device, rest) = line.split_once(':')?;
            let (kind, state) = rest.split_once(':')?;

            if kind != "wifi" || state != "connected" {
                return None;
            }

            if options
                .interface
                .as_deref()
                .is_some_and(|requested| requested != device)
            {
                return None;
            }

            Some(device.to_owned())
        });

        if let Some(device) = active {
            let status = Command::new("nmcli")
                .args([
                    "device",
                    "wifi",
                    "show-password",
                    "ifname",
                    &device,
                ])
                .stdin(Stdio::inherit())
                .stdout(Stdio::inherit())
                .stderr(Stdio::inherit())
                .status()
                .context(
                    "could not execute NetworkManager QR renderer",
                )?;

            ensure!(
                status.success(),
                "NetworkManager QR renderer failed: {status}"
            );

            return Ok(());
        }
    }

    let network = zbus::block_on(_connected(options.interface))?;
    sharing::print(&network)
}

async fn _connection() -> Result<zbus::Connection> {
    zbus::Connection::system()
        .await
        .context("could not connect to the system D-Bus")
}

async fn _objects(
    connection: &zbus::Connection,
) -> Result<zbus::fdo::ManagedObjects> {
    ObjectManagerProxy::builder(connection)
        .destination("net.connman.iwd")
        .path("/")
        .build()
        .await?
        .get_managed_objects()
        .await
        .context("could not access iwd; install iwd and follow the README migration procedure")
}

async fn _proxy<'a>(
    connection: &'a zbus::Connection,
    target: (&'a OwnedObjectPath, &'a str),
) -> Result<zbus::Proxy<'a>> {
    Ok(zbus::Proxy::new(
        connection,
        "net.connman.iwd",
        target.0,
        target.1,
    )
    .await?)
}

async fn _set_radio(enabled: bool) -> Result<()> {
    let connection = _connection().await?;
    let objects = _objects(&connection).await?;
    let adapters: Vec<_> = objects
        .iter()
        .filter(|(_, interfaces)| {
            interfaces.contains_key("net.connman.iwd.Adapter")
        })
        .collect();
    ensure!(!adapters.is_empty(), "iwd found no Wi-Fi adapters");
    for (path, _) in adapters {
        _proxy(&connection, (path, "net.connman.iwd.Adapter"))
            .await?
            .set_property("Powered", enabled)
            .await
            .with_context(|| format!("iwd rejected radio change for {path}; check permissions and rfkill hardware/software blocks"))?;
    }
    Ok(())
}

async fn _connected(
    interface: Option<String>,
) -> Result<sharing::Network> {
    let connection = _connection().await?;
    let objects = _objects(&connection).await?;
    let mut stations: Vec<_> = objects
        .iter()
        .filter(|(_, interfaces)| {
            interfaces.contains_key("net.connman.iwd.Station")
        })
        .collect();
    stations.sort_by_key(|(path, _)| path.as_str());
    for (path, _) in stations {
        let device =
            _proxy(&connection, (path, "net.connman.iwd.Device"))
                .await?;
        let name: String = device.get_property("Name").await?;
        if interface
            .as_ref()
            .is_some_and(|requested| *requested != name)
        {
            continue;
        }
        let station =
            _proxy(&connection, (path, "net.connman.iwd.Station"))
                .await?;
        if station.get_property::<String>("State").await?
            != "connected"
        {
            continue;
        }
        let network_path: OwnedObjectPath =
            station.get_property("ConnectedNetwork").await?;
        let network = _proxy(
            &connection,
            (&network_path, "net.connman.iwd.Network"),
        )
        .await?;
        let known = objects
            .get(&network_path)
            .and_then(|interfaces| {
                interfaces.get("net.connman.iwd.Network")
            })
            .and_then(|properties| properties.get("KnownNetwork"))
            .map(|value| {
                value.try_clone().and_then(OwnedObjectPath::try_from)
            })
            .transpose()?;
        let hidden = match known {
            Some(path) if path.as_str() != "/" => {
                _proxy(
                    &connection,
                    (&path, "net.connman.iwd.KnownNetwork"),
                )
                .await?
                .get_property("Hidden")
                .await?
            }
            _ => false,
        };
        return Ok(sharing::Network {
            name: network.get_property("Name").await?,
            security: network.get_property("Type").await?,
            hidden,
        });
    }
    anyhow::bail!(
        "no connected iwd Wi-Fi station{}; connect through Impala after transferring the adapter to standalone iwd (README: Wi-Fi migration). Internet access through another interface or network daemon cannot be shared by iwd",
        interface
            .map(|name| format!(" on {name}"))
            .unwrap_or_default()
    )
}
