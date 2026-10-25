//! askprint <file.pdf> [printer name]   print a PDF on that printer (the default printer when no name is given)
//! askprint --list                      list the printers, the default one marked with *
//!
//! Exit codes: 0 printed (the spooler took the job and finished it), 2 no such printer, 3 the job failed, 4 bad arguments.
use std::path::Path;
use std::process::ExitCode;
use winprint::printer::{FilePrinter, PrinterDevice, WinPdfPrinter};
use winprint::ticket::{PrintTicket, PrintTicketBuilder};

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    match args.first().map(String::as_str) {
        Some("--list") => list(),
        Some(file) => print(file, args.get(1).map(String::as_str).unwrap_or("")),
        None => {
            eprintln!("usage: askprint <file.pdf> [printer name] | --list");
            ExitCode::from(4)
        }
    }
}

fn list() -> ExitCode {
    let default = PrinterDevice::user_default().ok().flatten().map(|d| d.name().to_string());
    match PrinterDevice::all() {
        Ok(all) => {
            for d in all {
                println!("{}{}", if default.as_deref() == Some(d.name()) { "*" } else { " " }, d.name());
            }
            ExitCode::SUCCESS
        }
        Err(e) => {
            eprintln!("cannot list printers: {e}");
            ExitCode::from(3)
        }
    }
}

fn print(file: &str, printer: &str) -> ExitCode {
    if !Path::new(file).is_file() {
        eprintln!("file not found: {file}");
        return ExitCode::from(4);
    }
    let device = if printer.is_empty() {
        match PrinterDevice::user_default() {
            Ok(Some(d)) => d,
            _ => {
                eprintln!("no default printer");
                return ExitCode::from(2);
            }
        }
    } else {
        match PrinterDevice::by_os_name(printer) {
            Ok(d) => d,
            Err(e) => {
                eprintln!("printer not found: {e}");
                return ExitCode::from(2);
            }
        }
    };
    // the driver's own defaults (paper size, tray, quality) checked against what the printer can do: what Word and the Windows PDF reader hand to the spooler
    let ticket = PrintTicketBuilder::new(&device).and_then(|b| b.build()).unwrap_or_else(|_| PrintTicket::default());
    match WinPdfPrinter::new(device).print(Path::new(file), ticket) {
        Ok(_) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("print failed: {e:?}");
            ExitCode::from(3)
        }
    }
}
