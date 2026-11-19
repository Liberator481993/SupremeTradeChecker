# Supreme Values Rust Core

This crate converts the compact JSON export produced by the MM2 in-game exporter into a stable, explicit catalogue JSON document for a Luau consumer.

## Scope

- Parses the compact export fields: category, item name, image name, value, demand, origin, event, year, rarity and tier.
- Keeps unpriced items as null; it never invents a zero value.
- Builds stable IDs from category + normalized item name.
- Preserves source and export timestamp metadata.
- Rejects empty exports and unsupported schema versions.

This is an offline data-normalization core. **It does not execute inside Roblox**: Roblox runs Luau, not native Rust. The intended boundary is Rust-generated JSON consumed by the in-game Luau script. This crate does not inject into Roblox, inspect memory, or automate trades.

## Run

    cargo test --manifest-path rust-core/Cargo.toml
    cargo run --release --manifest-path rust-core/Cargo.toml -- input-export.json catalogue.json

The input file is the JSON export from the existing exporter. The output is a normalized catalogue suitable for serving or bundling with the Luau script.

## Current limitation

The checked-in export snapshot was created on 2026-11-09. It is a historical snapshot, not a live Supreme Values feed. A refresh/publishing pipeline and Luau-side consumer still need to be connected and tested before values appear in MM2.
