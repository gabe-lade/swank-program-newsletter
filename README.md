# Swank Program in Rural-Urban Policy Newsletter

**Repository of code, data, and analyses**

This repository contains reproducible code and data for the [Swank Program in Rural-Urban Policy Newsletter](https://gelade1.substack.com), a publication exploring the intersection of rural and urban policy, economics, and data analysis.

## Repository Structure

Each subdirectory corresponds to a specific newsletter edition, organized by publication date in `YYYYMMDD` format. Within each folder, you'll find:

- **Code**: R scripts or other programming files used for analysis
- **Data**: Input datasets (where file sizes permit)
- **Figures**: Output visualizations and maps
- **README**: Detailed documentation explaining the analysis, data sources, and reproduction steps

### Example Structure

```
swank-program-newsletter/
├── 20250918-newsletter/     # Newsletter from September 18, 2025
│   ├── code/
│   ├── data/
│   ├── figures/
│   └── README.md
└── README.md               # This file
```

## About the Newsletter

The **Swank Program in Rural-Urban Policy Newsletter** provides data-driven analysis and insights on topics including:

- Agricultural economics and production trends
- Rural-urban development patterns
- Regional economic policy
- Land use and environmental change
- Demographic shifts and urbanization

Most newsletters focus on these issues in Ohio, but also provide national policy implications. 

**Subscribe**: [gelade1.substack.com](https://gelade1.substack.com)

## Reproducibility

All analyses are designed to be fully reproducible. Each newsletter folder contains:

1. Complete code with detailed comments
2. Information about required packages and dependencies
3. Instructions for obtaining necessary API keys or data sources
4. Step-by-step reproduction guides in individual README files

### Note on Data Availability

Due to GitHub file size limitations, some newsletters may not include raw data files directly in the repository. This typically occurs when:

- Raw datasets exceed GitHub's recommended file size limits
- Data files are particularly large (e.g., census block-level shapefiles)
- Preprocessed data files are too large to version control efficiently

**If you need access to raw data files that are not included in a specific folder**, please contact:

**Gabriel Lade**  
Email: [lade.10@osu.edu](mailto:lade.10@osu.edu)

## Getting Started

To reproduce any analysis:

1. Navigate to the newsletter folder of interest
2. Read the folder-specific README for detailed instructions
3. Install required packages and obtain any necessary API keys
4. Run the analysis scripts

Each folder's README provides complete setup instructions specific to that analysis.

## Contributing

While this repository primarily serves as an archive of newsletter analyses, feedback and suggestions are welcome. If you identify errors or have questions about specific analyses, please open an issue or contact Gabriel Lade directly.

## Contact

**Gabriel Lade**  
Email: lade.10@osu.edu  
Newsletter: [gelade1.substack.com](https://gelade1.substack.com)

## License

Code in this repository is available for educational and research purposes. When using or adapting this code:

- Please cite the Swank Program Newsletter and provide a link to the original analysis
- Acknowledge data sources as specified in individual README files
- Follow the terms of service for any APIs or data sources used

Data sourced from government agencies (USDA, Census Bureau, FRED, etc.) are in the public domain and should be cited appropriately.

---

*This repository supports the mission of making data-driven policy analysis transparent, reproducible, and accessible.*
