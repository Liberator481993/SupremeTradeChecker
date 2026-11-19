use std::{env, fs, process};

use supreme_values_core::parse_export;

fn run() -> Result<(), String> {
    let args: Vec<String> = env::args().collect();
    if args.len() != 3 {
        return Err(format!(
            "Usage: {} <input-export.json> <output-catalogue.json>",
            args.first().map(String::as_str).unwrap_or("supreme-values-core")
        ));
    }

    let input = fs::read_to_string(&args[1])
        .map_err(|error| format!("Cannot read {}: {error}", args[1]))?;
    let catalogue = parse_export(&input)?;
    let output = serde_json::to_string_pretty(&catalogue)
        .map_err(|error| format!("Cannot serialize catalogue: {error}"))?;

    fs::write(&args[2], output)
        .map_err(|error| format!("Cannot write {}: {error}", args[2]))?;

    println!(
        "Catalogue generated: {} items ({} priced, {} without values)",
        catalogue.item_count, catalogue.priced_count, catalogue.unpriced_count
    );
    Ok(())
}

fn main() {
    if let Err(error) = run() {
        eprintln!("{error}");
        process::exit(1);
    }
}
