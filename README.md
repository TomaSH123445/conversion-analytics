# E-commerce Marketing Conversion Analytics

## Project Overview

This project analyzes an e-commerce business using SQL, PostgreSQL, Python, pandas, and matplotlib.

The goal is to understand how website traffic converts into orders and revenue, identify the main drivers of business growth, evaluate product performance, and detect potential refund risks.

The project is structured as an end-to-end analytics case study, starting from raw data import and data quality checks, continuing through KPI calculation and business analysis, and preparing the project for a future Power BI dashboard.

---

## Business Objective

The main objective is to answer the following business questions:

1. What drives business growth over time?
2. Is growth caused by more traffic, better conversion, higher order value, or a combination of these factors?
3. How efficiently does website traffic convert into revenue?
4. How does the product mix change over time?
5. Which products generate the most value?
6. Which products create refund risk?
7. Which insights should be visualized in a future Power BI dashboard?

---

## Tools Used

- PostgreSQL
- SQL
- Python
- pandas
- matplotlib
- Jupyter Notebook
- GitHub

Power BI dashboard is planned as the next project layer.

---

## Dataset

The project uses an e-commerce database containing website sessions, pageviews, orders, order items, refunds, and products.

Main tables:

- `website_sessions`
- `website_pageviews`
- `orders`
- `order_items`
- `order_item_refunds`
- `products`

---

## Repository Structure

```text
ecommerce-marketing-conversion-analytics/
├── README.md
├── .gitignore
├── requirements.txt
├── data/
│   ├── raw/
│   └── processed/
├── docs/
│   ├── business_questions.md
│   ├── data_dictionary.md
│   ├── metric_definitions.md
│   └── business_insights.md
├── sql/
│   ├── 00_create_tables.sql
│   ├── 01_data_exploration.sql
│   ├── 02_data_quality_checks.sql
│   ├── 03_kpi_queries.sql
│   └── 04_business_analysis.sql
├── python/
│   └── notebooks/
│       └── 01_eda_validation.ipynb
├── powerbi/
│   └── README.md
└── images/
    └── README.md
```

---

## Project Workflow

### 1. Data Import and Database Setup

The raw CSV files were imported into PostgreSQL. Database tables were created using SQL scripts.

The project starts with:

```text
00_create_tables.sql
```

This script defines the database structure and relationships between tables.

---

### 2. Data Exploration

The file:

```text
01_data_exploration.sql
```

is used to understand the dataset structure, including:

- row counts,
- date ranges,
- available products,
- traffic sources,
- campaigns,
- device types,
- pageview URLs,
- landing pages.

---

### 3. Data Quality Checks

The file:

```text
02_data_quality_checks.sql
```

validates whether the data can be trusted.

Checks include:

- primary key uniqueness,
- primary key null checks,
- foreign key integrity,
- relationship cardinality,
- timestamp logic,
- refund logic.

Important validation results:

- Primary keys are unique and non-null.
- Foreign key relationships are valid.
- One website session has at most one order.
- Product-level analysis should be done using `order_items`.
- Refund logic is simple because one refunded item has at most one refund record.

---

### 4. KPI Calculation

The file:

```text
03_kpi_queries.sql
```

calculates the main business KPIs:

- total sessions,
- total orders,
- conversion rate,
- gross revenue,
- average order value,
- revenue per session,
- gross margin,
- gross margin rate,
- refund amount,
- net revenue,
- refund rate.

Core KPI results:

| Metric | Value |
|---|---:|
| Total Sessions | 472,871 |
| Total Orders | 32,313 |
| Conversion Rate | 6.83% |
| Gross Revenue | $1,938,509.75 |
| Average Order Value | $59.99 |
| Revenue per Session | $4.10 |
| Gross Margin | $1,216,139.50 |
| Gross Margin Rate | 62.74% |
| Total Refund Amount | $85,338.69 |
| Net Revenue | $1,853,171.06 |

---

### 5. Business Analysis

The file:

```text
04_business_analysis.sql
```

uses validated KPI logic to answer business questions.

Main analysis areas:

- monthly business performance,
- source and campaign performance,
- device opportunity analysis,
- product performance and refund risk,
- landing page performance,
- funnel step performance.

This part focuses on interpretation, comparison, and decision support rather than only calculating metrics.

---

### 6. Python EDA and Validation

The notebook:

```text
python/notebooks/Eda_validation.ipynb
```

validates SQL findings using Python and pandas.

Python was used for:

- validating core KPI values,
- monthly trend analysis,
- conversion rate visualization,
- revenue per session analysis,
- average order value analysis,
- average items per order analysis,
- product mix analysis,
- refund risk analysis.

This notebook confirms that the SQL results are consistent and provides visual support for the main business insights.

---

## Key Business Insights

### 1. Business growth is driven by multiple factors

Business growth is not driven only by traffic volume.

Sessions and orders grow over time, but conversion rate also improves significantly. This means the business becomes better at converting visitors into customers.

---

### 2. Revenue per session improves over time

Revenue per session increases over the dataset period.

This shows that the business is not only attracting more visitors, but also generating more revenue per visit.

---

### 3. Average order value increases around early 2014

Average order value increases significantly around early 2014.

This aligns with an increase in average items per order, suggesting that customers started buying larger baskets.

---

### 4. Product mix becomes more diversified

The Original Mr. Fuzzy starts as the dominant product, but other products gain share over time.

This suggests that the business becomes less dependent on a single product and starts benefiting from a broader product portfolio.

---

### 5. The Original Mr. Fuzzy is the main revenue driver

The Original Mr. Fuzzy has the highest number of items sold, gross revenue, and net revenue.

It remains the core product of the business.

---

### 6. The Birthday Sugar Panda has the highest refund risk

The Birthday Sugar Panda has the highest item refund rate.

This product should be investigated further from the perspective of product quality, customer expectations, and marketing messaging.

---

### 7. The Forever Love Bear is a healthy supporting product

The Forever Love Bear has solid revenue and a relatively lower refund rate.

It may be a good candidate for further promotion or cross-sell strategy.

---

## Python Visual Analysis

The Python notebook includes visual analysis for:

- monthly website sessions,
- monthly orders,
- conversion rate trend,
- revenue per session trend,
- average order value trend,
- average items per order,
- product sales by month,
- product mix share,
- product refund summary.

Planned image exports:

```text
images/monthly_sessions_trend.png
images/monthly_conversion_rate_trend.png
images/monthly_revenue_per_session_trend.png
images/monthly_average_order_value.png
images/monthly_product_mix_share.png
```

These images will be added to the README after final export.

---

## Power BI Dashboard Plan

A Power BI dashboard will be created as the next layer of the project.

Planned dashboard pages:

### 1. Executive Overview

Main KPIs:

- Total Sessions
- Total Orders
- Conversion Rate
- Gross Revenue
- Net Revenue
- Revenue per Session
- Gross Margin Rate
- Refund Share

Purpose:

Provide a high-level business overview.

---

### 2. Monthly Business Performance

Visuals:

- Sessions trend
- Orders trend
- Revenue trend
- Conversion rate trend
- Revenue per session trend
- Average order value trend

Purpose:

Show whether growth is driven by traffic, conversion, or order value.

---

### 3. Marketing Performance

Visuals:

- Sessions by source/campaign
- Revenue by source/campaign
- Conversion rate by source/campaign
- Revenue per session by source/campaign

Purpose:

Identify valuable acquisition channels and campaign combinations.

---

### 4. Product and Refund Analysis

Visuals:

- Revenue by product
- Net revenue by product
- Refund rate by product
- Product mix share
- Gross margin by product

Purpose:

Identify value-driving products and refund-risk products.

---

### 5. Funnel and Landing Page Analysis

Visuals:

- Funnel step conversion
- Funnel drop-off
- Landing page conversion rate
- Landing page revenue per session

Purpose:

Identify where users drop off before purchase.

---

## Skills Demonstrated

### SQL

- Joins
- LEFT JOIN logic
- CTEs
- Aggregations
- Date truncation
- KPI calculation
- Data quality checks
- Funnel analysis
- Business analysis queries

### PostgreSQL

- Table creation
- Data import
- Relational data modeling
- Query validation

### Python

- pandas data loading
- DataFrame validation
- groupby operations
- merge operations
- pivot tables
- KPI validation
- matplotlib visualizations
- trend analysis

### Business Analytics

- Conversion analysis
- Revenue analysis
- Product performance analysis
- Refund risk analysis
- Product mix analysis
- Basket size analysis
- Business insight generation

---

## Main Analytical Takeaway

The business grows through a combination of traffic growth, improving conversion efficiency, and increasing average order value.

The increase in average order value is strongly connected to larger baskets and a more diversified product mix.

The Original Mr. Fuzzy remains the main revenue driver, while The Birthday Sugar Panda should be investigated as the main refund-risk product.

---

## Next Steps

1. Finalize Python visual exports.
2. Add chart images to the README.
3. Build the Power BI dashboard.
4. Add Power BI screenshots to the `images/` folder.
5. Update the README with dashboard preview.
6. Prepare a short LinkedIn case study post.