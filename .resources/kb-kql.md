# Azure Data Explorer (Kusto) Development Best Practices in Microsoft Fabric

### Who are you?

You are a **KQL Developer** building and managing an Azure Data Explorer (ADX) Kusto database in Microsoft Fabric. This guide provides best practices and practical examples to help you design an efficient, maintainable, and high-performance Kusto database. It covers how to structure your data (using the medallion architecture), optimize KQL queries, and format KQL code for clarity and performance.

| Capability             | Scale          | Description                                                                                                     |
| ---------------------- | -------------- | --------------------------------------------------------------------------------------------------------------- |
| **Scalable Data**      | Petabyte-Scale | Azure Data Explorer can handle data from gigabytes to petabytes, with automatic scaling for massive throughput. |
| **Concurrent Queries** | Unlimited      | ADX supports virtually unlimited concurrent users and queries, auto-scaling to maintain performance under load. |
| **Real-Time Insights** | Immediate      | Data is queryable almost immediately after ingestion, enabling real-time analytics with low response times.     |

These capabilities set the stage for **real-time analytics** in Fabric. To fully leverage ADX, it’s critical to apply sound design principles and coding practices, as detailed below.

### Learning

Continuously improving your Kusto Query Language skills and ADX knowledge is essential. Here are key resources to further learning:

- **Kusto Query Language (KQL) Documentation** – _Microsoft Learn_: Official KQL overview and reference documentation. This covers KQL syntax, operators, and usage across Azure Data Explorer and Fabric.
- **KQL Learning Path** – _Microsoft Learn Training_: A guided learning path for data analysis with Kusto Query Language, including hands-on modules for building queries.
- **Medallion Architecture in Fabric (Real-Time Intelligence)** – _Microsoft Learn_: Guide on implementing the Bronze–Silver–Gold layered architecture in Fabric’s Real-Time analytics environment[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686)[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686), explaining how update policies and materialized views support ACID compliance and real-time processing.
- **Real-Time Medallion Architecture Blog** – _Microsoft Tech Community_: In-depth tutorial on building a real-time medallion architecture using Fabric Eventhouse (ADX) with an e-commerce example[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686)[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686). Provides step-by-step instructions and sample code for Bronze, Silver, and Gold layers.
- **ADX Best Practices** – _Azure Docs_: Best practice articles such as [Schema Optimization Best Practices][13] and performance tuning tips for Azure Data Explorer. These cover schema design (data types, indexing), query optimization, and cluster settings to avoid common pitfalls.

Each of these resources offers insight into writing efficient KQL and designing robust ADX solutions. They will help you avoid performance issues and follow proven patterns as you develop.

### Global Development Rules

When developing an ADX (Kusto) database in Fabric, follow these high-level best practices to ensure your solution is scalable, performant, and easy to maintain. These **global development rules** encompass data architecture, schema design, ingestion & transformation, and query optimization.

<!-- Copilot-Researcher-Visualization -->

| Best Practice                               | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| ------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Medallion Layers for Clear Architecture** | Organize data into **Bronze**, **Silver**, and **Gold** layers. This medallion architecture incrementally improves data quality and structure at each stage. Raw data lands in _Bronze_ (for capture and history), refined data is in _Silver_ (cleaned, deduplicated), and aggregated or business-ready data is in _Gold_ (optimized for analytics).                                                                                                      |
| **Real-Time Ingestion & Transformation**    | Use ADX **update policies** to automatically transform and enrich data as it moves from Bronze to Silver. This built-in streaming transformation capability removes the need for external ETL tools for real-time scenarios. Combine it with **retention policies** to clean up raw data when it's no longer needed.                                                                                                                                       |
| **Functions Over Views for Reusability**    | Use **functions** instead of views in Azure Data Explorer for better performance and flexibility. Functions can be called with parameters and are more efficient than views. Create functions with `.create function` and reference them in update policies instead of inline queries. Functions support proper documentation with docstrings and can be tested independently.                                                                             |
| **Proper KQL Deployment Syntax**            | Use consolidated deployment scripts with direct KQL commands. Separate multiple commands with semicolons when needed. Avoid multiple nested `.execute script` calls. Azure Data Explorer doesn't support traditional database indexes - rely on automatic column indexing instead. Use single consolidated deployment scripts with proper command sequencing for better maintainability and compatibility.                                                 |
| **Optimize Schema and Queries**             | Design an efficient schema: use proper data types and avoid overly wide tables. For example, store timestamps as `datetime` (not long) and only use `decimal` when exact precision is needed. Keep tables "narrow" (fewer columns) when possible and denormalize data during ingestion to reduce expensive joins at query time. **Filter data early** in queries (use `where` before aggregating) and select only needed columns to minimize scanned data. |

Let's break down these principles and others in more detail:

#### **1. Adopt the Medallion Architecture (Bronze–Silver–Gold Layers)**

Structure your Kusto database into logical layers to improve data quality step-by-step:

- **Bronze Layer – Raw Data**: This is the landing zone for all incoming data (streams or batch). Store data exactly as received from source systems. **Goal/Requirement**: Capture all events or source records (including possible duplicates or PII) for auditing and replay if needed[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686)[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686). Bronze tables often retain history; you can apply a **retention policy** if you only need to keep a window of raw data (for example, 30 days of log data). If no immediate cleanup is needed, choose an appropriate retention period or keep indefinitely for audit.
- **Silver Layer – Clean & Enriched Data**: This layer refines the Bronze data. Use transformation logic to clean, deduplicate, and enrich the data. **Goal**: Provide anonymized or enhanced data ready for broad internal use (no raw PII, consistent formats)[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686)[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686). For instance, parse JSON text into columns, calculate new fields, or remove duplicates. In Fabric, **update policies** can automatically take data from a Bronze table and insert the transformed result into a Silver table in near-real-time[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686)[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686). Set the update policy’s **IsTransactional** to _true_ so that if the transformation fails, the Bronze data isn’t lost. You may also choose to remove processed data from Bronze after it’s in Silver. One method is to set a very short soft-delete period (e.g. 0 seconds) on the Bronze table’s retention policy so that as soon as data is ingested and forwarded to Silver, it’s dropped from Bronze[2](https://learn.microsoft.com/en-us/azure/data-explorer/schema-best-practice). This keeps Bronze as a transient staging area if long-term raw storage isn’t required.
- **Gold Layer – Aggregated & Curated Data**: The Gold layer contains data ready for analytics and reporting – typically aggregated metrics or the latest state of records. **Goal**: Optimize for end-user queries and BI dashboards, with high performance[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686)[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686). Gold tables are often created via **materialized views** that aggregate Silver data. For example, you might maintain a Gold table of the _latest_ version of each record (deduplicated by an ID with most recent timestamp) or daily summary statistics[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686)[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686). Materialized views in ADX ensure the Gold data is always fresh and can be queried much faster than computing aggregations on the fly[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686)[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686). If you join multiple Silver tables for a final output, you could use an update policy or scheduled job to populate a Gold table, or even create a materialized view that joins and summarizes in one step. The Gold layer should be what your dashboards and reports query for the most efficient results.

In practice, adopting this layered approach improves both **clarity** (each layer has a clear purpose and audience) and **efficiency** (less processing needed at query time as data is prepped in stages). The table below maps each layer to its typical contents and purpose:

| **Layer (Table Prefix)**        | **Contents & Purpose (Requirement)**                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Bronze** (`Raw*` tables)      | Raw source data as ingested. Captures all events/records, possibly with duplicates or PII. _Requirement:_ act as the immutable data lake (audit trail) and initial ingestion point[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686)[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686).                             |
| **Silver** (`Silver*` tables)   | Cleaned, deduplicated, and enriched data. Personal data is removed or anonymized; new useful columns added. _Requirement:_ provide high-quality, query-ready data for internal analysis and to feed Gold layer[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686)[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686). |
| **Gold** (`Gold*` tables/views) | Curated, aggregated data, often in the form of materialized views or final fact tables. _Requirement:_ support fast BI queries and dashboards with pre-aggregated results or the latest record state[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686)[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686).           |

_(In Azure Fabric Real-Time Analytics, an “Eventstream” feeds Bronze, and an “Eventhouse” KQL database contains the tables.)_

Using consistent naming (like prefixing table names with Bronze/Silver/Gold or similar) is recommended to quickly identify a table’s role. For example, in a sales analytics scenario you might have `SalesOrderHeader` in Bronze, `SilverSalesOrderHeader` with cleansed orders, and a `GoldSalesSummary` view with aggregated sales metrics. This convention makes the architecture self-documenting.

#### **2. Optimize Schema Design and Data Modeling**

A well-designed schema is key to both query performance and ease of use:

- **Choose Appropriate Data Types**: Use native types that best represent the data. For instance, store dates/times in the `datetime` type (rather than as longs or strings) to enable time-aware functions and efficient storage[2](https://learn.microsoft.com/en-us/azure/data-explorer/schema-best-practice). Use `real` (floating point) for numerical data unless exact precision is absolutely required – excessive use of `decimal` can slow down queries significantly[2](https://learn.microsoft.com/en-us/azure/data-explorer/schema-best-practice). For key identifiers (IDs, GUIDs), Azure Data Explorer best practice is often to store them as strings (not integers) because string-typed IDs can be indexed and partitioned more effectively[2](https://learn.microsoft.com/en-us/azure/data-explorer/schema-best-practice). Avoid using the `dynamic` type for frequently-accessed fields; instead, extract those fields into dedicated columns of a proper type[2](https://learn.microsoft.com/en-us/azure/data-explorer/schema-best-practice). Reserve `dynamic` (JSON blobs) for semi-structured data or very sparse attributes that you don’t often filter or aggregate on.
- **Narrow vs. Wide Tables**: Keep your tables as “narrow” as makes sense – avoid hundreds of seldom-used columns in one table[2](https://learn.microsoft.com/en-us/azure/data-explorer/schema-best-practice). Each column in ADX is indexed, so extremely wide tables can increase ingestion cost and memory usage. Instead, consider splitting into multiple tables or grouping rarely-used fields. If you have more than ~20 columns that are mostly null or not queried, consider storing them as a single dynamic column (JSON object) rather than separate columns[2](https://learn.microsoft.com/en-us/azure/data-explorer/schema-best-practice). This way, your frequently queried columns remain few and efficiently indexed.
- **Denormalization and Enrichment**: Joins in ADX are possible, but for high-throughput analytics it’s often better to **denormalize upfront**. That means incorporating reference data (dimensions) into your facts during ingestion, so queries don’t have to join at runtime[2](https://learn.microsoft.com/en-us/azure/data-explorer/schema-best-practice). For example, if you ingest a log with a user ID, you might enrich it by looking up the user’s department name during ingestion (via an update policy or data pipeline) and store that in the table. This avoids a join on every query for department. However, if the reference data changes frequently or is too large to replicate, you have options:
  - **External Tables**: ADX allows creating external tables that point to external data sources (SQL, storage etc.)[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686). In Fabric, for instance, you could create an external table that connects directly to an operational SQL database’s dimension table (as shown in the Eventhouse example for products[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686)). This way, your Kusto queries can join to up-to-date reference data without you ingesting it into ADX. Be cautious with performance though – external joins may be slower and depend on the external source’s availability.
  - **Materialized Views for Latest Dimensions**: If you denormalize data that can become outdated (e.g., a product name that might be updated later), one strategy is to maintain a Gold materialized view that always picks the latest information. For instance, you can ingest product data into Bronze/Silver and use `arg_max(timestamp, *) by ProductID` in a materialized view to keep only the latest record per product[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686). This ensures even denormalized data stays current.
- **Indexing and Partitioning**: Azure Data Explorer automatically indexes all columns, but you can adjust indexing policies if needed. For columns that are never used in search or filters, you can disable indexing (using an encoding policy with the `BigObject` profile) to reduce ingestion overhead[2](https://learn.microsoft.com/en-us/azure/data-explorer/schema-best-practice). Also consider using the built-in time partitioning: ADX data is implicitly partitioned by ingestion time. Always include a timeframe filter (e.g. `| where Timestamp > ago(30d)`) in queries whenever possible to take advantage of this partition pruning. If you have a very large data volume and a frequently-filtered column (like a `TenantID` or `DeviceID` in multi-tenant data), you may consider using **partitioning** in the table schema (ADX supports one partition key, which must be a string column). Partitioning by a high-cardinality identifier or by a date can improve query efficiency on that dimension, but note it impacts how data is distributed in storage.

#### **3. Ingestion and Transformation Best Practices**

Efficient data ingestion and real-time transformation are core strengths of ADX in Fabric:

- **Use Update Policies for Stream Processing**: Update policies let you define a query that runs on incoming data of a source table to produce data in a target table[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686)[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686). They are ideal for implementing the Bronze→Silver flow. For example, when data arrives in a Bronze table, an update policy can automatically apply a function to cleanse the data and insert it into a Silver table. This happens behind the scenes on each batch of ingested data. Ensure your update policy queries are idempotent (or use transactional mode) and as lightweight as possible (they should focus on one table’s transformation). Complex transformations might be broken into multiple steps or functions. The **docstring** feature allows you to document your transformation functions for clarity[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686).
- **Batch vs. Streaming**: ADX can ingest data continuously (streaming via Eventstream) or in micro-batches. If using Eventstream in Fabric, consider its event processing capabilities to filter or route data even before it hits the Bronze table[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686). For batch ingestion (e.g., using Fabric Data Pipelines or Azure Data Factory), try to batch many records per ingestion call to amortize overhead. ADX is optimized for heavy ingestion, but very small trickles can be less efficient.
- **Ingestion Time Policy**: Enable the **ingestion time policy** on tables to automatically record an `_ingestion_time()` for each record[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686)[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686). ADX can add a hidden `IngestionTime` column or you can explicitly create a column for it. This is useful for debugging lag and for building retention policies or incremental processing (like identifying new data arrival times). In KQL, you can access ingestion time via the `ingestion_time()` function. In the medallion pattern, you might carry this forward as a standard field (as shown by adding `IngestionDate=datetime` in Silver tables and populating it via update policy[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686)).
- **Retention Policies**: Set retention (soft-delete) policies on your tables appropriate to their purpose. This prevents uncontrolled data growth and controls costs. For example, if Bronze is just a staging area, you might set its retention to a short duration (e.g., 1-7 days) after which data is dropped, once you are sure it made it to Silver/Gold. Conversely, if Bronze is meant to keep full history, set a longer retention or none. Silver tables might keep data longer, but if you create intermediate helper tables (like a staging table used only to deduplicate into a materialized view), you can even set retention to 0 days – meaning the data is immediately removed after ingestion, effectively making the table ephemeral[2](https://learn.microsoft.com/en-us/azure/data-explorer/schema-best-practice). Gold tables often represent aggregated results over long periods, but if they are materialized views, they maintain themselves based on their source data retention. Always review that your retention policies align with business requirements (compliance or analysis needs) and ensure no critical data is prematurely deleted.

#### **4. Aggregation and Query Performance**

Design your solution so that most heavy lifting is done _before_ the end-user queries, and apply query optimizations:

- **Materialized Views for Aggregation**: As noted, materialized views are ideal for pre-aggregating data continuously. Use them for common rollups (e.g., total events per hour, latest state of a record, rolling averages) so that queries against these results incur minimal computation at runtime[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686)[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686). In ADX, materialized views update as new data arrives, and you can specify `backfill=true` to initialize them with historical data[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686). They are especially useful in the Gold layer to provide **always-fresh** dashboard data. Keep the aggregation query of a materialized view as simple as needed (they currently can’t do extremely complex calculations or multi-step logic – those should be done in Silver prepares). Remember that a materialized view can source from a table _or_ another materialized view (allowing multi-hop aggregation if needed).
- **Efficient Query Patterns**: When writing KQL queries (for analysts or for building dashboards), follow best practices to make them run faster:
  - Always **filter early**: Use `where` as one of the first operators in your query to restrict to the smallest data relevant[3](https://kql.how/query/best-practices-for-kql-queries/best-practices-for-kql-queries/). For example, if querying a year of data but only need the last 7 days, filter by timestamp upfront.
  - **Select only necessary columns** with `project` or by specifying them in summarize/joins. Avoid `*` wildcards which force scanning all columns[3](https://kql.how/query/best-practices-for-kql-queries/best-practices-for-kql-queries/). This reduces data shuffled through the query.
  - Use the appropriate aggregation functions. For counting rows, prefer `summarize count()` or `countif()` rather than using the standalone `count` operator (the standalone count reads all rows; a summarize with count can leverage indexing to count faster)[3](https://kql.how/query/best-practices-for-kql-queries/best-practices-for-kql-queries/). Similarly, use `summarize` with group-by for counting by category instead of filtering multiple times.
  - Exploit specialized operators: e.g., use `makenull` / `coalesce` for null handling, `bin()` for time bucketing, `make-series` for creating time series on the fly[3](https://kql.how/query/best-practices-for-kql-queries/best-practices-for-kql-queries/), or the `top-nested` or `top-hitters` plugins for efficient top-N analysis. These are optimized implementations compared to manual workarounds.
  - Limit usage of expensive operations on large data: for instance, regular expressions (`matches` or `extract`) across an entire dataset can be slow. If possible, parse or extract needed info at ingestion time (store it in a column), or apply regex only after filtering down to a smaller subset.
  - **Join and Lookup considerations**: If you must join in a query, ensure one side of the join is significantly smaller (use the _broadcast join_ pattern with `hint.strategy=broadcast` when a left side is up to ~100 MB)[3](https://kql.how/query/best-practices-for-kql-queries/best-practices-for-kql-queries/). Or, use the `lookup` operator if it’s a simple key-value look-up from a small reference table (a few MB)[3](https://kql.how/query/best-practices-for-kql-queries/best-practices-for-kql-queries/). Always project away unneeded columns before a join to minimize data movement. And if joining across clusters or databases, try to run the query on the cluster where most data resides, pulling the smaller set over[3](https://kql.how/query/best-practices-for-kql-queries/best-practices-for-kql-queries/).
  - **Query results caching**: ADX has an automatic query results cache. If you have heavy repeated queries, consider using the [cache] function or the `materialize()` function for subquery results to avoid recomputation[3](https://kql.how/query/best-practices-for-kql-queries/best-practices-for-kql-queries/). Also, ensure the cluster’s hot cache is effectively used; in Fabric, much of this is managed behind the scenes with auto-scale, but designing queries to hit similar patterns can improve cache hits.
- **Scaling Considerations**: In Fabric, your ADX (Eventhouse) operates within a capacity. If you notice sustained high load, you might need to adjust capacity or scale settings. The good news is ADX in Fabric will auto-scale resources to an extent[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686). Still, extremely heavy queries can be slow; consider breaking them into smaller pieces or using background jobs to precompute results (again, materialized views or scheduled queries writing to tables).
- **Monitoring and Iteration**: Use the monitoring tools available – e.g., the `.show queries` command to find long-running queries, or metrics for ingestion rate and cache utilization. Tune queries iteratively: the Kusto web UI “Explain” or “Insights” features can help identify which part of a query is the bottleneck. Also leverage the **Kusto Advisor** (if available) which can suggest optimizations like creating materialized views or partitioning a table based on your query patterns.

#### **5. Security and Governance**

Security is another important aspect, though not deeply covered by this question’s scope. In a best practice context, consider:

- **Access Control**: Use Azure RBAC and ADX’s role-based access to limit who can view or alter data. You can assign database Viewer, Monitor, User, Ingestor, or Admin roles to different personas. For instance, give analysts read-only query access to Silver/Gold, while only data engineers have rights to create tables or alter policies.
- **Row-Level and Column-Level Security**: If certain data is sensitive, ADX supports row-level security policies and column masking. Design your schema such that applying these is straightforward (for example, separate PII fields into a different table if they often need restricted access).
- **Resource Governance**: Implement throttling or limits if needed using policies – for example, restricting heavy queries or setting a maximum ingestion rate, to protect the cluster from misuse.

#### **6. Integration and Lifecycle Management**

One advantage of using ADX in Fabric is its integration with other services:

- **OneLake Integration**: Data in an ADX KQL database can be exposed to OneLake in Delta Parquet format automatically[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686). This means you get the performance of ADX for querying, _and_ the data is available in a lake for other engines (Spark, Power BI, SQL, etc.) in a consistent format. Embrace this “open data” approach – it prevents lock-in and allows cross-service analytics. Ensure your Fabric KQL database’s OneLake export is enabled if you want to use this feature.
- **Connectivity**: You can query ADX data from Power BI (via DirectQuery or the Kusto connector) to build dashboards. Follow Microsoft’s guidance for best performance (for example, aggregating on the Kusto side as much as possible before results reach Power BI). You can also connect Fabric notebooks via the Spark connector to run Spark computations on KQL data[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686).
- **DevOps for KQL**: Treat your KQL schema and functions as code. Keep .kql or .csl scripts in source control for all your table schemas, functions, and policies. This way you can recreate the database in a new environment or track changes. Use automation (Azure DevOps, GitHub Actions, or Fabric pipelines) to deploy changes to your ADX database, especially for production environments.

By adhering to these global rules, you set up a strong foundation for your Azure Data Explorer database. You reduce common errors (like missing data due to improper policies, or slow queries from poor schema design) and ensure the system can scale with your needs.

### KQL Formatting Rules

Writing KQL queries and commands in a clean, consistent style is important for collaboration and long-term maintainability. Here are formatting best practices for KQL, with examples:

- **Readable Layout**: **Avoid one-liners** – break complex queries into multiple lines. Each pipeline operator (`|`) should typically start a new line, and subsequent clauses in the query should be indented. This makes it easy to follow the sequence of transformations[4](https://veldify.com/2025/06/26/best-practices-for-documenting-and-organizing-kql/). For example, instead of:

  ```kusto
  CommonSecurityLog | where not(disabled) | where TimeGenerated <= ago(5m)
  ```

  write:

  ```kusto
  CommonSecurityLog
  | where not(disabled)
  | where TimeGenerated <= ago(5m)
  ```

  Each filter or operation is on its own line above, improving clarity[4](https://veldify.com/2025/06/26/best-practices-for-documenting-and-organizing-kql/).

- **Alignment and Spacing**: Align similar elements vertically where it aids readability. For instance, in a `let` statement or function signature with many parameters, you can align the `=` signs or type declarations. Ensure there is space around operators (`=`, `==`, `<`, etc.) for readability[4](https://veldify.com/2025/06/26/best-practices-for-documenting-and-organizing-kql/). Avoid trailing spaces at end of lines. Keep indentation consistent (e.g. 4 spaces or 2 spaces – pick a standard). Don’t over-indent beyond what’s needed to show hierarchy; extremely deep indentation can be hard to read in the Kusto web UI.

- **Comments**: Use comments liberally to explain non-obvious logic. KQL supports single-line comments starting with `//`. There is no multi-line comment, but you can start each line with `//` for block comments. Place comments **above** the line or section they describe, or at end-of-line if short. For example, when creating a table or setting a policy, include a comment describing its purpose, e.g.:

  ```kusto
  // Create raw Address table (Bronze layer)
  .create table [Address] (
      AddressID:int,
      AddressLine1:string,
      City:string,
      PostalCode:string,
      ModifiedDate:datetime
  )
  // Enable ingestion time policy to track data arrival time
  .alter table Address policy ingestiontime true
  ```

  In the above snippet, the first comment documents the table’s intent (Bronze layer for raw addresses) and the second comment explains why we alter the ingestion time policy[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686)[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686). This makes the script self-explanatory for future maintainers.

- **Organization of KQL Script**: When building a Kusto database, organize your KQL management commands in a logical sequence. A typical script order might be:

  1. **Table and Schema Definitions** – Use `.create table ...` for each table with its schema. Group tables by layer or domain, and add comments as shown. Example: first all Bronze tables, then Silver, etc.
  2. **Table Policies** – After creating tables, apply policies: e.g., `.alter table X policy retention ...`, `.alter table X policy ingestiontime true`, `.alter table Y policy update ...`, `.create materialized-view ...`. Keep the policy commands immediately after the table they apply to, along with comments. This way, someone reading the script sees a table definition followed by its relevant settings. For instance, creating a Silver table and right after, adding the update policy that populates it from Bronze ensures context is together.
  3. **Functions** – If you use helper functions (via `.create function`), define them before the update policies or queries that use them. Include a **docstring** in your functions to describe what they do[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686). For example:
     ```kusto
     .create function with (docstring = "Add ingestion time to raw data")
     ParseAddress() {
         Address
         | extend IngestionDate = ingestion_time()
     }
     ```
     This function (ParseAddress) takes data from the `Address` table and adds an ingestion timestamp. The docstring provides inline documentation. Such a function can then be referenced in an update policy or in queries.
  4. **Queries or Views** – If you have saved queries or need to create certain views (materialized views or functions for querying), include them after the data transformation definitions.

- **Example – Table, Update Policy, and Materialized View**: Below is a simplified example that ties together table creation, an update policy via a function, and a materialized view. It demonstrates good formatting and commenting practices:

  ```kusto
  // Bronze table: Raw Orders (full history, with PII fields)
  .create table OrdersRaw (
      OrderID:int,
      CustomerName:string,   // PII: will be removed in Silver
      ProductID:int,
      Quantity:int,
      OrderDate:datetime,
      LastUpdate:datetime
  )
  // Apply ingestion time policy for latency tracking
  .alter table OrdersRaw policy ingestiontime true

  // Silver table: Cleaned Orders (no PII, plus new computed fields)
  .create table SilverOrders (
      OrderID:int,
      ProductID:int,
      Quantity:int,
      OrderDate:datetime,
      LastUpdate:datetime,
      CustomerID:string,
      IngestedOn: datetime    // added field for ingestion time
  )
  // Function to transform raw orders to silver (remove name, add ID and timestamp)
  .create function with (docstring="Transform raw orders to silver layer")
  TransformOrder() {
      OrdersRaw
      | extend CustomerID = hash(CustomerName)         // pseudo-anonymize customer
      | extend IngestedOn = ingestion_time()           // capture ingestion time
      | project-away CustomerName                     // drop PII field
  }
  // Update policy: use TransformOrder to populate SilverOrders whenever OrdersRaw receives new data
  .alter table SilverOrders policy update @'[
      {
          "Source": "OrdersRaw",
          "Query": "TransformOrder",
          "IsEnabled": true,
          "IsTransactional": true
      }
  ]'

  // Gold view: Latest Orders (only the most recent record per OrderID)
  .create materialized-view with (backfill=true) LatestOrders on table SilverOrders {
      SilverOrders
      | summarize arg_max(LastUpdate, *) by OrderID
  }
  ```

  In this example:

  - Comments clearly label each section (Bronze table, Silver table, function, update policy, Gold view) and even note a PII field[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686).
  - The KQL commands are split into logical blocks with blank lines in between for readability.
  - Long lines (like the update policy JSON) are kept mostly intact but could be formatted with line breaks if needed (as long as JSON string format is preserved).
  - The function `TransformOrder` has a docstring and is formatted with the pipeline on new lines, making it easy to read what transformations occur.
  - The materialized view creation is on multiple lines inside the braces for clarity. It uses `arg_max(LastUpdate, *) by OrderID` to keep only the latest order update per order, fulfilling a typical Gold layer requirement.

- **Consistent Naming**: Use a consistent naming convention for schema objects and functions. For example, use PascalCase or snake_case for table names (e.g. `OrdersRaw` or `orders_raw` – pick one style and stick to it). Prefixing tables with their layer as discussed (SilverOrders, GoldSales) is helpful. Function names typically use PascalCase (e.g. `TransformOrder`), and you might prefix functions with a verb or category (e.g. `fnParseAddress` could be a naming pattern). Consistency in naming makes scripts predictable and easier to navigate.

- **Testing Queries**: When you write complex queries, build them step by step, testing each part. Utilize the Kusto Explorer or web UI to format the query for you (there’s a “Format” button that will apply a default style if needed). A well-formatted query not only reduces the chance of mistakes but also makes optimization easier (you can spot which part of the query is doing what at a glance).

By following these KQL formatting rules, your code will be easier to understand and maintain. Well-formatted queries and commands, coupled with adequate commenting, act as documentation for your system. Future you (or other team members) will thank you when they can quickly grasp the logic without deciphering a wall of text. Consistent style also reduces coding errors – e.g., missing a parenthesis is less likely when the structure is indented clearly.

#### **2.1. KQL Syntax Best Practices for Azure Data Explorer**

Working with Azure Data Explorer requires specific KQL syntax practices that differ from traditional databases:

- **Use Functions Instead of Views**: Azure Data Explorer optimizes functions better than views. Functions can be parameterized, reused in update policies, and provide better performance for complex logic:

  ```kusto
  // ✅ Good: Create a function for reusable logic
  .create function parse_generators_data() {
      power_generators_raw
      | where ingestion_time() > ago(5m)
      | extend parsed_data = parse_json(raw_data)
      | extend generator_id = tostring(parsed_data.ActorName)
      | project generator_id, power_production, efficiency_percent
  }

  // ❌ Avoid: Views are less efficient and harder to parameterize
  .create view generator_view as
      power_generators_raw | extend parsed_data = parse_json(raw_data)
  ```

- **Consolidated Deployment Scripts**: Avoid multiple nested `.execute script` blocks in deployment scripts. Instead, use direct KQL commands with proper semicolon separation:

  ```kusto
  // ✅ Good: Direct commands with semicolons
  .drop table power_generators ifexists;
  .create table power_generators (
      generator_id: string,
      power_production: real,
      efficiency_percent: real
  );
  .alter table power_generators policy retention "{"SoftDeletePeriod": "90.00:00:00"}";

  // ❌ Avoid: Multiple nested execute blocks
  .execute script <|
      .drop table power_generators ifexists
      .create table power_generators (...)
  |>
  .execute script <|
      .alter table power_generators policy retention ...
  |>
  ```

- **No Manual Indexing Required**: Azure Data Explorer automatically indexes all columns. Don't try to create traditional database indexes:

  ```kusto
  // ✅ Good: Let ADX handle indexing automatically
  .create table power_generators (
      generator_id: string,
      timestamp: datetime,
      power_production: real
  )

  // ❌ Avoid: Manual index creation (not supported in ADX)
  .create table power_generators policy indexes [
      {"IndexName": "idx_generator_id", "Columns": ["generator_id"]}
  ]
  ```

- **Function References in Update Policies**: Use function names in update policies instead of inline queries for better maintainability:

  ```kusto
  // ✅ Good: Reference a function in update policy
  .alter table power_generators policy update @'[
      {
          "Source": "power_generators_raw",
          "Query": "parse_generators_data()",
          "IsEnabled": true,
          "IsTransactional": true
      }
  ]'

  // ❌ Avoid: Inline complex queries in policies
  .alter table power_generators policy update @'[
      {
          "Source": "power_generators_raw",
          "Query": "power_generators_raw | where ingestion_time() > ago(5m) | extend ...",
          "IsEnabled": true
      }
  ]'
  ```

- **Proper Command Termination**: Use semicolons to separate KQL management commands, especially in deployment scripts:

  ```kusto
  // ✅ Good: Proper command separation
  .drop function parse_generators_data ifexists;
  .create function parse_generators_data() { ... };
  .alter table power_generators policy update @'[...]';

  // ❌ Avoid: Missing semicolons can cause parsing errors
  .drop function parse_generators_data ifexists
  .create function parse_generators_data() { ... }
  .alter table power_generators policy update @'[...]'
  ```

- **Deployment Script Structure**: Organize deployment scripts in logical phases with clear separation and validation:

  ```kusto
  // Phase 1: Create Tables
  print "📋 Phase 1: Creating Tables...";
  .drop table power_generators ifexists;
  .create table power_generators (...);

  // Phase 2: Create Functions
  print "📋 Phase 2: Creating Functions...";
  .drop function parse_generators_data ifexists;
  .create function parse_generators_data() { ... };

  // Phase 3: Create Update Policies
  print "📋 Phase 3: Creating Update Policies...";
  .alter table power_generators policy update @'[...]';

  // Phase 4: Validation
  print "🔍 Phase 4: Validation...";
  .show tables | where TableName == "power_generators";
  .show functions | where Name == "parse_generators_data";
  ```

---

**Conclusion:** Developing a Kusto database in Azure Data Explorer (especially within Microsoft Fabric) involves careful planning of your data architecture and diligent application of best practices. By organizing data into Bronze, Silver, Gold layers, you ensure a clear flow from raw data to actionable insights. By optimizing schema and using features like update policies, ingestion time, and materialized views, you achieve real-time data processing with reliable performance. And by writing clean, well-documented KQL code, you prevent errors and make ongoing development much more efficient. Following the guidelines in this document will help avoid common pitfalls (such as performance bottlenecks or messy code) and set you up for success in your KQL development projects. Always keep learning and refer back to Microsoft’s documentation and community blogs for the latest recommendations as the platform evolves[1](https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/building-a-real-time-medallion-architecture-using-eventhouse-in-microsoft-fabric/4110686)[3](https://kql.how/query/best-practices-for-kql-queries/best-practices-for-kql-queries/). Happy querying!
