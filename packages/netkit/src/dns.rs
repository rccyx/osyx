use anyhow::{Context, Result};
use clap::Args;
use hickory_resolver::{Resolver, proto::rr::RecordType};
use tokio::runtime::Builder;

#[derive(Args)]
pub struct Lookup {
    /// DNS name to query
    pub name: String,
    /// Record type: A, AAAA, MX, TXT, NS, CNAME, SOA, PTR, ...
    #[arg(default_value = "A")]
    pub record_type: RecordType,
}

pub fn lookup(query: Lookup) -> Result<()> {
    Builder::new_current_thread()
        .enable_all()
        .build()
        .context("could not start DNS runtime")?
        .block_on(_lookup(query))
}

#[expect(clippy::print_stdout, reason = "DNS answers are CLI output")]
async fn _lookup(query: Lookup) -> Result<()> {
    let resolver = Resolver::builder_tokio()
        .context("could not read system DNS configuration")?
        .build()
        .context("could not initialize DNS resolver")?;
    let records =
        resolver.lookup(query.name, query.record_type).await?;
    for record in records.answers() {
        println!("{record}");
    }
    Ok(())
}
