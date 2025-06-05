# PolyLens 360 — Multi-Asset Portfolio Stress Lab

**Objective**: Build an interactive Power BI / Tableau workspace that stress-tests, narrates, and visually explores simultaneous market, liquidity, and ESG shocks across traditional, crypto, and private-debt holdings in minutes.

## Repository Structure

```
PolyLens360/
├── README.md
├── ingestion/
│   ├── pdf_scraper/
│   │   ├── Cargo.toml
│   │   └── src/main.rs
│   └── collector/
│       ├── go.mod
│       └── collector.go
├── streaming/
│   └── FinRiskETL/
│       ├── build.sbt
│       └── src/main/scala/FinRiskETL.scala
├── risk_engine/
│   ├── monte_copula.cu
│   ├── pybind_wrapper.cpp
│   ├── pyproject.toml
│   └── setup.py
├── rstats/
│   └── fit_risk_model.R
├── api/
│   ├── main.py
│   └── requirements.txt
├── sql/
│   ├── create_tables.sql
│   └── create_views.sql
├── visuals/
│   └── shock_cone.vega.json
├── powerbi/
│   └── dax_examples.txt
├── infrastructure/
│   └── main.tf
└── docker-compose.yml
```

## Execution Plan

| Phase | Weeks  | Goals & Deliverables                                                                                                                           | Languages / Tech                           |
|-------|--------|-------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------|
| **P0 – Scoping & Infra Setup**   | 0–1    | • Provision cloud accounts (Azure/AWS).<br>• Create Power BI workspace / Tableau project.<br>• Set up Kafka cluster and Delta Lake / Iceberg storage. | Terraform, SQL, Docker                     |
| **P1 – Data Collectors & Ingestion** | 2–4    | • Build Rust service to scrape covenant PDFs → JSON.<br>• Build Go service to tap CEX + DeFi feeds → Kafka.<br>• Validate streams in Kafka UI. | Rust, Go, Kafka, Docker                    |
| **P2 – Data Lake & ETL (Spark)** | 5–7    | • Write Spark (Scala) jobs to consume Kafka topics and land raw tables (Delta) every 5 min.<br>• Build Python notebooks to clean reference data and push to Delta.<br>• Create SQL views for marts. | Scala, Python, SQL, Delta Lake             |
| **P3 – Risk Engine (C++ & CUDA)**  | 8–11   | • Implement Copula-Monte-Carlo library in C++17 with CUDA (<10k paths in <1s).<br>• Expose gRPC interface accepting shocks → returns portfolio returns.<br>• `pybind11` wrapper so Python can call simulate. | C++17, CUDA, pybind11, gRPC                |
| **P4 – Statistical Fitting (R)**   | 12–14  | • Write R script to fit GARCH + vine-copula to historical returns nightly.<br>• Output parameters JSON to “param_store” Delta table.<br>• Schedule via cron / Azure Data Factory. | R, rvinecopulib, SQL, cron                 |
| **P5 – API Layer (FastAPI)**      | 15–16  | • Build FastAPI exposing `/stress?scenario=…` → loads latest params, calls C++ gRPC, merges with covenants & ESG, returns JSON.<br>• `/explain?return=…` → shapley drivers.<br>• Containerize and deploy to Azure App Service / AWS Fargate. | Python (FastAPI), C++, gRPC, Docker         |
| **P6 – Semantic Model & BI Prep**  | 17–19  | • Define star schema in Power BI / Tableau: fact_mart, dim_asset, dim_time, dim_scenario, dim_covenant.<br>• Create DAX measures / Tableau calcs: Residual_VaR, ESG_Shock %, Liquidity_Heat_Index.<br>• Set up DirectQuery to Delta / Synapse. | Power BI (DAX), Tableau (Calc), SQL        |
| **P7 – Custom Visuals & Storyboard** | 20–22  | • Develop custom Vega/JS visual (3D shock cone) and embed in Power BI / Tableau.<br>• Build Liquidity Heat-Grid: minute-level depth map via Python → CSV/Delta; link to BI.<br>• Create storyboard: “Flash Crash 2010” drill-through, “Luna 2022” case study.<br>• Configure auto-refresh every 60 s. | JavaScript (Vega), Python, R, Power BI, Tableau |
| **P8 – Pilot Testing & Validation** | 23–24  | • Ingest 6 months of historical data for test portfolios.<br>• Validate risk metrics vs historical losses.<br>• User validation with portfolio manager; feedback on latency & visuals.<br>• Write white paper / blog post. | Python, SQL, Power BI/Tableau, Markdown     |
| **P9 – Wrap-up & Deployment**      | 25–26  | • Optimize performance: DirectQuery <5s.<br>• Harden security: secure keys, OAuth2 for API, row-level security in BI.<br>• Publish Power BI report (or Tableau) with auto-refresh.<br>• Release code on GitLab/GitHub with CI pipeline.<br>• Present to stakeholders. | DevOps: Terraform/ARM, Docker, Power BI Admin |

---

## Quick Start (Local Mock)

1. **Start Kafka & PostgreSQL** (for Delta simulation) via Docker:
    ```bash
    docker-compose up -d
    ```

2. **Ingestion**:
    - **Rust PDF Scraper**:
      ```bash
      cd ingestion/pdf_scraper
      cargo build --release
      mkdir -p covenants && # place PDFs in covenants/
      ./target/release/pdf_scraper
      ```
    - **Go Collector**:
      ```bash
      cd ../../ingestion/collector
      go mod tidy
      go run collector.go
      ```

3. **Spark ETL** (requires Spark 3.4+ with Delta):
    ```bash
    cd ../../streaming/FinRiskETL
    sbt assembly
    spark-submit       --class FinRiskETL       --master local[*]       target/scala-2.12/FinRiskETL_2.12-0.1.jar
    ```

4. **Risk Engine**:
    ```bash
    cd ../../../risk_engine
    python -m pip install .
    python - <<EOF
    import mc_copula
    res = mc_copula.simulate(10000, 252, 0.0, 0.2, 100.0)
    print("VaR_95:", sorted(res)[int(0.05*len(res))])
    EOF
    ```

5. **Statistical Fitting**:
    ```bash
    cd ../rstats
    # Ensure historical_returns.csv is present
    Rscript fit_risk_model.R
    ```

6. **API Layer**:
    ```bash
    cd ../api
    pip install -r requirements.txt
    uvicorn main:app --reload --port 8000
    curl -X POST http://localhost:8000/stress -H "Content-Type: application/json" -d '{"scenario":"Test"}'
    ```

7. **SQL Schema & Views**:
    ```sql
    -- Connect to your SQL engine and run:
    \i sql/create_tables.sql
    \i sql/create_views.sql
    ```

8. **Custom Visual**:
    - In Power BI: Use “HTML Viewer” custom visual or “Web Content” to load `visuals/shock_cone.vega.json`.
    - In Tableau: Use “Web Data Connector” pointing to a local HTML page embedding Vega.

9. **BI Setup**:
    - Open Power BI Desktop / Tableau Desktop.
    - Connect to SQL views.
    - Add DAX measures from `powerbi/dax_examples.txt`.

---

## Deliverables

- **ingestion/pdf_scraper/**: Rust-based covenant PDF scraper producing JSON to Kafka.
- **ingestion/collector/**: Go-based real-time CEX & DeFi feed collector to Kafka.
- **streaming/FinRiskETL/**: Spark (Scala) streaming job writing Delta tables.
- **risk_engine/**: CUDA-based Copula-Monte-Carlo library with Python wrapper.
- **rstats/**: R script to fit GARCH + vine-copula, outputting JSON parameters.
- **api/**: FastAPI micro-service exposing stress-testing endpoints.
- **sql/**: SQL scripts for schema and views (DirectQuery).
- **visuals/**: Vega JSON for 3D shock cone.
- **powerbi/**: DAX examples for Power BI semantic model.
- **infrastructure/**: Terraform template to provision Pulsar tenant.
- **docker-compose.yml**: Local Kafka & Postgres setup.

---

## Notes

- Replace placeholder endpoints, credentials, and file paths as needed.
- For production, secure all secrets and enable proper authentication.
- Extend and optimize each component for robustness, error handling, and scale.
