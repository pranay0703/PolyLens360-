name := "FinRiskETL"
version := "0.1"
scalaVersion := "2.12.18"

libraryDependencies ++= Seq(
  "org.apache.spark" %% "spark-sql"            % "3.4.0",
  "org.apache.spark" %% "spark-sql-kafka-0-10" % "3.4.0",
  "io.delta"         %% "delta-core"           % "2.3.0"
)
