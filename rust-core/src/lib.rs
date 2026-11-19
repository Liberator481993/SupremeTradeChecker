use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize)]
struct RawExport {
    source: Option<String>,
    exported_at: Option<String>,
    schema_version: Option<u32>,
    entries: Vec<RawEntry>,
}

#[derive(Debug, Deserialize)]
struct RawEntry {
    #[serde(rename = "c")] category: String,
    #[serde(rename = "n")] name: String,
    #[serde(rename = "im")] image_name: Option<String>,
    #[serde(rename = "v")] value: Option<f64>,
    #[serde(rename = "dm")] demand: Option<String>,
    #[serde(rename = "o")] origin: Option<String>,
    #[serde(rename = "e")] event: Option<String>,
    #[serde(rename = "y")] year: Option<String>,
    #[serde(rename = "cl")] rarity: Option<String>,
    #[serde(rename = "t")] tier: Option<String>,
}

#[derive(Debug, Clone, Serialize, PartialEq)]
pub struct CatalogueItem {
    pub id: String,
    pub name: String,
    pub image_name: Option<String>,
    pub category: String,
    pub value: Option<f64>,
    pub demand: Option<String>,
    pub origin: Option<String>,
    pub event: Option<String>,
    pub year: Option<String>,
    pub rarity: Option<String>,
    pub tier: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct Catalogue {
    pub schema_version: u32,
    pub source: String,
    pub source_exported_at: Option<String>,
    pub item_count: usize,
    pub priced_count: usize,
    pub unpriced_count: usize,
    pub items: Vec<CatalogueItem>,
}

fn normalize_name(name: &str) -> String {
    name.trim().to_lowercase().replace('’', "'").replace('‘', "'")
        .split_whitespace().collect::<Vec<_>>().join(" ")
}

pub fn parse_export(input: &str) -> Result<Catalogue, String> {
    let raw: RawExport = serde_json::from_str(input)
        .map_err(|error| format!("Invalid Supreme Values export: {error}"))?;

    if raw.schema_version.is_some_and(|version| version != 1) {
        return Err("Unsupported Supreme Values export schema version".to_string());
    }
    if raw.entries.is_empty() {
        return Err("Supreme Values export contains no entries".to_string());
    }

    let mut items = Vec::with_capacity(raw.entries.len());
    for entry in raw.entries {
        let name = entry.name.trim().to_string();
        let category = entry.category.trim().to_lowercase();
        if name.is_empty() || category.is_empty() { continue; }
        let id = format!("{category}:{}", normalize_name(&name));
        let value = entry.value.filter(|v| v.is_finite() && *v >= 0.0);
        items.push(CatalogueItem {
            id, name, image_name: entry.image_name, category, value,
            demand: entry.demand, origin: entry.origin, event: entry.event,
            year: entry.year, rarity: entry.rarity, tier: entry.tier,
        });
    }

    if items.is_empty() {
        return Err("No valid catalogue entries found".to_string());
    }
    let priced_count = items.iter().filter(|item| item.value.is_some()).count();
    let item_count = items.len();
    Ok(Catalogue {
        schema_version: 1,
        source: raw.source.unwrap_or_else(|| "Supreme Values".to_string()),
        source_exported_at: raw.exported_at,
        item_count, priced_count, unpriced_count: item_count - priced_count, items,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn preserves_unpriced_items_as_null_instead_of_zero() {
        let input = r#"{"source":"Supreme Values","exported_at":"2026-11-09 20:40:28","schema_version":1,"entries":[{"c":"godlies","v":5100,"im":"Travelers Gun","dm":"5","o":"Halloween","n":"Traveler's Gun"},{"c":"misc","t":"x2 T1 Commons","im":"Candies (2017)","dm":"1","o":"Halloween","n":"Candies (2017)"}]}"#;
        let catalogue = parse_export(input).expect("valid export");
        assert_eq!(catalogue.item_count, 2);
        assert_eq!(catalogue.priced_count, 1);
        assert_eq!(catalogue.unpriced_count, 1);
        assert_eq!(catalogue.items[0].value, Some(5100.0));
        assert_eq!(catalogue.items[1].value, None);
    }

    #[test]
    fn rejects_empty_exports() {
        assert!(parse_export(r#"{"entries":[]}"#).is_err());
    }

    #[test]
    fn normalizes_curly_apostrophes_for_stable_ids() {
        let catalogue = parse_export(r#"{"entries":[{"c":"godlies","n":"Traveler’s Gun","v":5}]}"#).unwrap();
        assert_eq!(catalogue.items[0].id, "godlies:traveler's gun");
    }

    #[test]
    fn rejects_unknown_export_schema() {
        assert!(parse_export(r#"{"schema_version":2,"entries":[{"c":"godlies","n":"Test"}]}"#).is_err());
    }
}
