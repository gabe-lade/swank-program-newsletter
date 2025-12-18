# Ohio Property Tax Analysis: School District Millage Rates

Analysis and visualization of Ohio school district millage rates and the impact of HB 186 property tax reforms.

## Overview

This project analyzes how Ohio's 2024 property tax reforms (HB 186) affect school districts differently based on whether they are at the 20-mill floor. The analysis combines:

- School district millage rate data from the Ohio Department of Education (Tax Year 2024)
- Geographic boundaries from the U.S. Census Bureau TIGER/Line shapefiles (2023)
- Real-world property tax examples from Greene County

## Key Findings

**Two Different Tax Systems:**
- **356 districts (62%)** are at the 20-mill floor and lost automatic revenue growth under HB 186
- **217 districts (38%)** are above the floor and were already protected by HB 920

**Geographic Pattern:**
- Rural and exurban districts: predominantly at 20-mill floor
- Urban and suburban districts: predominantly above 20-mill floor

## Project Structure

```
.
├── code/
│   └── ohio_tax_analysis.R       # Main analysis script
├── data-raw/
│   └── 2024-sd-rates.xlsx        # School district millage rates from Ohio Dept of Education
├── output/
│   ├── ohio_school_districts_floor_map.png      # Statewide map
│   └── greene_county_tax_comparison.png         # Property tax comparison chart
└── README.md
```

## Requirements

R packages:
- `tidyverse`
- `sf`
- `readxl`
- `scales`
- `tigris`
- `viridis`

Install all dependencies:
```r
install.packages(c("tidyverse", "sf", "readxl", "scales", "tigris", "viridis"))
```

## Usage

Run the analysis script:
```r
source("code/ohio_tax_analysis.R")
```

The script will:
1. Download Ohio unified school district boundaries from Census TIGER/Line
2. Read and process the millage rate data
3. Merge datasets using numeric keys (93.6% match rate)
4. Generate two visualization outputs in the `output/` folder

## Data Sources

**School District Millage Rates:**
- Source: Ohio Department of Education, Tax Year 2024
- File: `data-raw/2024-sd-rates.xlsx`
- Contains Class I (residential/agricultural) and Class II (commercial/industrial) millage rates for all Ohio school districts

**Geographic Boundaries:**
- Source: U.S. Census Bureau TIGER/Line Shapefiles (2023)
- Type: Unified School Districts
- Note: Ohio only has unified school districts (K-12), no separate elementary/secondary districts

**Greene County Property Tax Data:**
- Source: Greene County Auditor property records
- Two comparable properties in different school districts, both reappraised in 2023

## Methodology

### Data Merge Strategy

The script uses a numeric merge key rather than string matching:
- Census GEOIDFQ format: `9700000US3904518`
- Extract last 4 digits: `4518`
- Match to first 4 digits of Ohio IRN (Information Retrieval Number): `45187` → `4518`

This achieves a **93.6% match rate** (573 of 612 districts).

### Color Scheme

Maps use Ohio State University colors:
- **Scarlet (#ba0c2f)**: Districts at 20-mill floor
- **Gray (#a7b1b7)**: Districts above 20-mill floor
- **White**: Missing data

## Visualizations

### 1. Statewide School District Map
Shows all Ohio school districts colored by their status relative to the 20-mill floor.

### 2. Greene County Property Tax Comparison
Line chart comparing property tax increases for two homes in different districts (Cedarville at floor vs. Bellbrook above floor) following the 2023 reappraisal.

## Technical Notes

- **Ohio has only unified school districts** in the Census TIGER data (no separate secondary districts)
- The 20-mill floor threshold is defined as `Class.I.20.mill.Floor.Rate <= 20.01` to allow for rounding
- Geographic projections use sf defaults (WGS84)
- Output maps are 300 DPI PNG files suitable for publication

## Related Policy Context

**HB 920 (1976):** Protected homeowners from automatic tax increases due to property reappraisals by adjusting millage rates downward. Only benefited districts above the 20-mill floor.

**HB 186 (2024):** Extended HB 920 protections to all districts, including those at the 20-mill floor. However, this eliminated the automatic revenue growth that floor districts previously received during reappraisals.

## License

This analysis is part of the Swank Program Newsletter. Data sources are publicly available from Ohio Department of Education and U.S. Census Bureau.

## Contact

For questions or issues, please open an issue on the [GitHub repository](https://github.com/gabe-lade/swank-program-newsletter).
