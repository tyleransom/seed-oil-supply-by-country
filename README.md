# FAO Seed Oil Data Harmonization

This project harmonizes FAO (Food and Agriculture Organization) data on seed oil supply across two methodological periods: 1961-2013 and 2010-2022.

## Problem

FAO changed its data collection methodology around 2014, creating discontinuities in time series data for seed oil supply. The overlapping period (2010-2013) shows systematic differences between the old and new methodologies.

## Harmonization Method

1. **Calculate adjustment factors**: For each country-item combination, compute the mean difference between new and old methodology values during the overlap period (2010-2013)

2. **Adjust historical data**: Add the calculated adjustment factor to all pre-2014 values using the old methodology

3. **Combine series**: Use adjusted old methodology data for 1961-2013 and new methodology data for 2014-2022

## Data Sources

**Pre-2014 data (1961-2013)**: [FAOSTAT Food Balance Sheets Historic](https://www.fao.org/faostat/en/#data/FBSH)
**Post-2014 data (2010-2022)**: [FAOSTAT Food Balance Sheets](https://www.fao.org/faostat/en/#data/FBS)

Data includes all countries and covers 9 oil types: soybean, groundnut, sunflowerseed, rapeseed/mustard, cottonseed, sesame, ricebran, maize germ, and other oilcrops.

## Output

The harmonized dataset provides consistent time series for:
- **Element Code 645**: Food supply quantity (kg/capita/year) 
- **Element Code 664**: Food supply energy (kcal/capita/day)

Two versions are exported:
- `seed-oils-all.csv`: All oil categories
- `seed-oils-6-largest.csv`: Excludes minor categories (other oilcrops, groundnut, sesame)

## Oil Categories Included

- Soybean oil
- Corn (maize) oil  
- Canola (rapeseed) oil
- Cottonseed oil
- Sunflowerseed oil
- Peanut (groundnut) oil
- Other oilcrops (optional)

## Usage

Run `src/harmonizeFAO.R` with the raw CSV files in the `data/raw/` directory to generate harmonized datasets in `data/cleaned/`.