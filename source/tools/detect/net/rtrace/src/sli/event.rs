use crate::sli_bindings::*;
use anyhow::{bail, Result};
use std::fmt;
use std::net::{IpAddr, Ipv4Addr, SocketAddr, SocketAddrV4};

pub struct LatencyHist {
    overflow: u32,
    latency: [u32; MAX_LATENCY_SLOTS as usize],
}

impl LatencyHist {
    pub fn new(ptr: *const latency_hist) -> LatencyHist {
        unsafe {
            let mut latency = [0; MAX_LATENCY_SLOTS as usize];
            for (i, j) in (*ptr).latency.into_iter().enumerate() {
                latency[i] = j;
            }

            LatencyHist {
                overflow: (*ptr).overflow,
                latency,
            }
        }
    }
}

impl fmt::Display for LatencyHist {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        let mut cnt = 0;
        let mut new_latency = [0; MAX_LATENCY_SLOTS as usize / 8]; // 16

        for (i, j) in self.latency.into_iter().enumerate() {
            cnt += j;
            new_latency[i / 8] += j;
        }

        if cnt == 0 {
            cnt = 1;
        }

        for (i, j) in new_latency.into_iter().enumerate() {
            let probablity = j * 100 / cnt;
            write!(
                f,
                "{:<4}-{:<4} | {:<100} {}\n",
                i * 64,
                (i + 1) * 64,
                "*".repeat(probablity as usize),
                j
            )?;
        }
        write!(f, "execced {} ms times: {}", MAX_LATENCY_MS, self.overflow)
    }
}

pub struct LatencyEvent {
    src: SocketAddr,
    dst: SocketAddr,
    latency: u32,
}

impl LatencyEvent {
    pub fn new(ptr: *const latency_event) -> LatencyEvent {
        let daddr = unsafe { (*ptr).ap.daddr };
        let dport = unsafe { (*ptr).ap.dport };
        let saddr = unsafe { (*ptr).ap.saddr };
        let sport = unsafe { (*ptr).ap.sport };
        let src = SocketAddr::new(IpAddr::V4(Ipv4Addr::from(u32::from_be(saddr))), sport);
        let dst = SocketAddr::new(IpAddr::V4(Ipv4Addr::from(u32::from_be(daddr))), dport);
        LatencyEvent {
            latency: unsafe { (*ptr).latency },
            src,
            dst,
        }
    }
}

impl fmt::Display for LatencyEvent {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(
            f,
            "{} -> {}, latency: {}ms",
            self.src, self.dst, self.latency
        )
    }
}

pub enum Event {
    LatencyEvent(LatencyEvent),
}

impl Event {
    pub fn new(ptr: *const event) -> Result<Event> {
        let et = unsafe { (*ptr).event_type } as u32;
        match et {
            LATENCY_EVENT => Ok(Event::LatencyEvent(LatencyEvent::new(unsafe {
                &(*ptr).__bindgen_anon_1.le
            }))),
            _ => {
                bail!("Can't recognize event type: {}", et)
            }
        }
    }
}