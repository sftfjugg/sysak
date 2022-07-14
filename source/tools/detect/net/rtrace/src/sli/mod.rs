mod event;

use eutils_rs::proc::Snmp;
mod sli;
use anyhow::{bail, Result};
use event::Event;
use event::LatencyHist;
use sli::Sli;
use std::{thread, time};
use structopt::StructOpt;

#[derive(Debug, StructOpt)]
pub struct SliCommand {
    #[structopt(long, help = "Collect retransmission metrics")]
    retran: bool,
    #[structopt(long, help = "Collect latency metrics")]
    latency: bool,
    #[structopt(long, default_value = "3", help = "Data collection cycle, in seconds")]
    period: u64,
}

pub struct SliOutput {
    // retranmission metrics
    // retran = (RetransSegs－last RetransSegs) ／ (OutSegs－last OutSegs) * 100%
    outsegs: isize, // Tcp: OutSegs
    retran: isize,  // Tcp: RetransSegs

    drop: u32,

    latencyhist: LatencyHist,

    events: Vec<Event>,
}

fn snmp_delta(old: &Snmp, new: &Snmp, key: (&str, &str)) -> Result<isize> {
    let lookupkey = (key.0.to_owned(), key.1.to_owned());
    let val1 = old.lookup(&lookupkey);
    let val2 = new.lookup(&lookupkey);

    if let Some(x) = val1 {
        if let Some(y) = val2 {
            return Ok(y - x);
        }
    }

    bail!("failed to find key: {:?}", key)
}

fn latency_sli(sli: &mut Sli) -> Result<()> {
    Ok(())
}

pub fn build_sli(opts: &SliCommand) -> Result<()> {
    let mut old_snmp = Snmp::from_file("/proc/net/snmp")?;
    let delta_ns = opts.period * 1_000_000_000;
    let mut sli = Sli::new(log::log_enabled!(log::Level::Debug))?;
    let mut sli_output: SliOutput = unsafe { std::mem::MaybeUninit::zeroed().assume_init() };
    let mut pre_ts = 0;

    if opts.latency {
        sli.attach_latency()?;
    }

    loop {
        if let Some(event) = sli.poll(std::time::Duration::from_millis(100))? {
            // log::debug!("{}", event);
            sli_output.events.push(event);
        }

        let cur_ts = eutils_rs::timestamp::current_monotime();
        if cur_ts - pre_ts < delta_ns {
            continue;
        }

        pre_ts = cur_ts;

        let new_snmp = Snmp::from_file("/proc/net/snmp")?;

        if opts.retran {
            sli_output.outsegs = snmp_delta(&old_snmp, &new_snmp, ("Tcp:", "OutSegs"))?;
            sli_output.retran = snmp_delta(&old_snmp, &new_snmp, ("Tcp:", "RetransSegs"))?;

            println!(
                "OutSegs: {}, Retran: {}",
                snmp_delta(&old_snmp, &new_snmp, ("Tcp:", "OutSegs"))?,
                snmp_delta(&old_snmp, &new_snmp, ("Tcp:", "RetransSegs"))?,
            );
        }

        if opts.latency {
            if let Some(x) = sli.lookup_and_update_latency_map()? {
                sli_output.latencyhist = x;
            }
        }

        old_snmp = new_snmp;
    }
}
