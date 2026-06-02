# FAO Seed Oil Data Harmonization

This project harmonizes FAO (Food and Agriculture Organization) data on seed oil supply across two methodological periods: 1961-2013 and 2010-2022.

## Problem

FAO changed its data collection methodology around 2014, creating discontinuities in time series data for seed oil supply. The overlapping period (2010-2013) shows systematic differences between the old and new methodologies.

## Harmonization Method

Growth-rate backcasting (chain-link splice), applied per country × element × oil item:

1. **Find anchor**: Identify the earliest year in the overlap period (2010–2013) where both the new methodology value and the old methodology value are present and `Old > 0`.

2. **Backcast pre-period years**: For years before the anchor, set `harmonized = New[anchor] × Old_t / Old[anchor]`. This scales the old series proportionally to the new series' level, preserving year-over-year growth rates from the old methodology.

3. **Use new methodology for covered years**: Where new methodology data exist, `harmonized = New`.

**Why backcasting instead of an additive shift**: The previous method added a constant `mean(New − Old)` offset to all pre-2014 values. Because seed-oil consumption grew several-fold over 1961–2013, that offset (estimated at high modern levels) drove early-year values negative (e.g., Canada 1961). Backcasting scales proportionally, is continuous at the anchor year, and cannot go negative when `Old ≥ 0`.

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

The script uses relative paths and must be run from `src/`:

```bash
cd src && Rscript harmonizeFAO.R
```

Raw CSV files must be in `data/raw/`; harmonized outputs are written to `data/cleaned/`.

## Disclaimer
I used Claude Code to assist with implementation.
