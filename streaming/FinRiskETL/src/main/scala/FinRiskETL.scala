import org.apache.spark.sql.SparkSession
import org.apache.spark.sql.functions._
import io.delta.tables._

object FinRiskETL {
  def main(args: Array[String]): Unit = {
    val spark = SparkSession.builder()
      .appName("FinRisk ETL")
      .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension")
      .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog")
      .getOrCreate()

    import spark.implicits._

    // Read CEX orderbook stream from Kafka
    val cexRaw = spark.readStream
      .format("kafka")
      .option("kafka.bootstrap.servers", "localhost:9092")
      .option("subscribe", "orderbook_cx")
      .selectExpr("CAST(value AS STRING) as json_str")
      .select(from_json($"json_str",
        schema_of_json("{\"u\":0,\"s\":\"BTCUSDT\",\"b\":\"0.0\",\"B\":\"0.0\",\"a\":\"0.0\",\"A\":\"0.0\"}")
      ).as("data"))
      .selectExpr("data.s as symbol", "data.b as bid_price", "data.B as bid_qty", "data.a as ask_price", "data.A as ask_qty", "current_timestamp() as ts")

    cexRaw.writeStream
      .format("delta")
      .outputMode("append")
      .option("checkpointLocation", "/tmp/finrisk/ckpt/cex")
      .option("path", "/tmp/finrisk/delta/cex_snapshot")
      .start()

    // Read DeFi events stream from Kafka
    val defiRaw = spark.readStream
      .format("kafka")
      .option("kafka.bootstrap.servers", "localhost:9092")
      .option("subscribe", "defi_events")
      .selectExpr("CAST(value AS STRING) as json_str")
      .select(from_json($"json_str", schema_of_json("{\"method\":\"eth_subscribe\",\"params\":{}}")).as("data"))
      .selectExpr("data.method as event", "current_timestamp() as ts")

    defiRaw.writeStream
      .format("delta")
      .outputMode("append")
      .option("checkpointLocation", "/tmp/finrisk/ckpt/defi")
      .option("path", "/tmp/finrisk/delta/defi_events")
      .start()

    spark.streams.awaitAnyTermination()
  }
}
