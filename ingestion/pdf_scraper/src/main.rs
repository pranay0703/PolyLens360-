use anyhow::Result;
use rdkafka::producer::{FutureProducer, FutureRecord};
use rdkafka::ClientConfig;
use regex::Regex;
use serde_json::json;
use std::{fs, time::Duration};

#[tokio::main]
async fn main() -> Result<()> {
    let producer: FutureProducer = ClientConfig::new()
        .set("bootstrap.servers", "localhost:9092")
        .set("message.timeout.ms", "5000")
        .create()?;

    let pattern = Regex::new(r"([A-Za-z0-9 ]+):\s*([0-9]+\.[0-9]+)")?;

    fs::create_dir_all("./covenants")?;

    for entry in fs::read_dir("./covenants")? {
        let path = entry?.path();
        if path.extension().and_then(|s| s.to_str()) == Some("pdf") {
            let txt_path = format!("{}.txt", path.display());
            std::process::Command::new("pdftotext")
                .arg(&path)
                .arg(&txt_path)
                .status()?;
            let text = fs::read_to_string(&txt_path)?;
            for cap in pattern.captures_iter(&text) {
                let rule = json!({
                    "source_pdf": path.file_name().unwrap().to_string_lossy(),
                    "item": &cap[1],
                    "threshold": cap[2].parse::<f64>()?,
                });
                let record = FutureRecord::to("cov_rules")
                    .payload(&rule.to_string())
                    .key(&path.file_name().unwrap().to_string_lossy());
                producer.send(record, Duration::from_secs(0)).await?;
            }
            fs::remove_file(&txt_path)?;
        }
    }
    println!("PDF scraping complete.");
    Ok(())
}
