# BIG SALES DATA DATA PREPARATION REPOSITORY
PROJECT SUMMARY
The project processes 14204 transaction records across 10 retail outlets and 1559 product items. The objective is to clean raw data to prepare for sales analysis.
METHODOLOGY
The SQL script standardizes fat content labels to Reduced Fat and Full Fat. The logic imputes 2389 missing weight values using a per SKU median calculation. The script applies a category level median fallback for weights. The process replaces zero visibility values with the median visibility of the specific item from other outlets. The code groups 16 original item types into 6 main product categories.
ANALYTICAL CRITIQUE
The previous text included strategic recommendations and key findings regarding revenue shares. The provided SQL script only performs data extraction and transformation. The code does not contain aggregation queries to calculate total revenue or outlet performance. Stating business findings in this description misrepresents the repository contents. The files function solely as a data engineering pipeline. You need a separate analytical script to validate the business claims.
AUTHOR
Laodi Antonius Sijabat
