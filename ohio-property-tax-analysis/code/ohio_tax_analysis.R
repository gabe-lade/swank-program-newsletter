# Ohio Property Tax Reform Analysis
# Real-world examples and geographic visualization
# Author: Your Name
# Date: December 2024

library(tidyverse)
library(sf)
library(readxl)
library(scales)
library(tigris)
library(viridis)

# Set options
options(tigris_use_cache = TRUE)


# ============================================================================
# STATEWIDE MAPS
# ============================================================================

# Read school district millage data
sd_data <- read_excel("data-raw/2024-sd-rates.xlsx", skip = 3)

# Clean column names
names(sd_data) <- make.names(names(sd_data))

# Identify districts at the 20-mill floor
# Floor rate should be very close to 20.000
sd_data <- sd_data %>%
  mutate(
    at_floor = Class.I.20.mill.Floor.Rate <= 20.01,  # Allow small rounding
    irn = Information.Retrieval.Number,
    district_name = School.District.Name,
    county_name = Home.County.Name,
    floor_rate = Class.I.20.mill.Floor.Rate
  ) %>%
  select(irn, district_name, county_name, floor_rate, at_floor)

# Download Ohio school district boundaries from Census
# Ohio only has unified districts (K-12), no separate secondary districts
ohio_districts <- school_districts(state = "OH", type = "unified", year = 2023)

cat(sprintf("✓ Downloaded %d school district boundaries\n", nrow(ohio_districts)))

# Match districts to millage data
# Use numeric merge: last 4 digits of GEOIDFQ match first 4 digits of IRN
# Example: GEOIDFQ "9700000US3904518" -> "4518" matches IRN 45187 -> "4518"

# Create merge key from Census GEOIDFQ (last 4 digits)
ohio_districts <- ohio_districts %>%
  mutate(merge_key = str_sub(GEOIDFQ, -4, -1))

# Create merge key from Excel IRN (first 4 digits)
sd_data <- sd_data %>%
  mutate(merge_key = str_sub(as.character(irn), 1, 4))

# Join data using numeric merge key
ohio_map <- ohio_districts %>%
  left_join(sd_data, by = "merge_key") %>%
  mutate(
    floor_status = case_when(
      is.na(at_floor) ~ "No data",
      at_floor ~ "At 20-mill floor",
      TRUE ~ "Above 20-mill floor"
    ),
    floor_status = factor(floor_status, 
                          levels = c("At 20-mill floor", 
                                     "Above 20-mill floor", 
                                     "No data"))
  )

cat(sprintf("\n✓ Matched %d districts with millage data\n", 
            sum(!is.na(ohio_map$at_floor))))

# Create map
p2 <- ggplot(ohio_map) +
  geom_sf(aes(fill = floor_status), color = "white", linewidth = 0.1) +
  scale_fill_manual(
    values = c(
      "At 20-mill floor" = "#ba0c2f",      # Ohio State Scarlet
      "Above 20-mill floor" = "#a7b1b7",   # Ohio State Gray
      "No data" = "white"
    ),
    name = "District Status",
    drop = FALSE
  ) +
  labs(
    title = "Ohio School Districts: Two Different Tax Systems",
    subtitle = sprintf("%d districts at 20-mill floor (%.0f%%) | %d above floor", 
                       sum(ohio_map$at_floor, na.rm = TRUE),
                       mean(ohio_map$at_floor, na.rm = TRUE) * 100,
                       sum(!ohio_map$at_floor, na.rm = TRUE)),
    caption = "Source: Ohio Department of Education, Tax Year 2024\nScarlet districts: At 20-mill floor, lost automatic revenue growth under HB 186\nGray districts: Above floor, already protected by HB 920, minimal impact from reforms"
  ) +
  theme_void(base_size = 22) +
  theme(
    plot.title = element_text(face = "bold", size = 28, margin = margin(b = 10)),
    plot.subtitle = element_text(color = "gray30", size = 22, margin = margin(b = 20)),
    plot.caption = element_text(hjust = 0, size = 18, color = "gray50", margin = margin(t = 20)),
    legend.position = c(0.85, 0.05),
    legend.background = element_rect(fill = "white", color = "gray80"),
    legend.title = element_text(size = 22),
    legend.text = element_text(size = 20),
    plot.margin = margin(20, 20, 20, 20)
  )

ggsave("output/ohio_school_districts_floor_map.png",
       p2, width = 10, height = 12, dpi = 300, bg = "white")

cat("\n✓ Statewide map saved\n")






# ============================================================================
# PART 1: Real World Example - Greene County Tax Bills
# ============================================================================

# Two real houses in Greene County (reappraised in 2023)
# Bellbrook (above 20-mill floor) vs Cedarville (at 20-mill floor)

tax_data <- tribble(
  ~district, ~year, ~taxes, ~status,
  "Bellbrook", 2022, 3662, "Above floor",
  "Bellbrook", 2023, 4162, "Above floor", 
  "Bellbrook", 2024, 4114, "Above floor",
  "Cedarville", 2022, 1436, "At 20-mill floor",
  "Cedarville", 2023, 1902, "At 20-mill floor",
  "Cedarville", 2024, 1860, "At 20-mill floor"
)

# Calculate index (2022 = 100)
tax_index <- tax_data %>%
  group_by(district) %>%
  mutate(
    base_year_tax = taxes[year == 2022],
    index = (taxes / base_year_tax) * 100
  ) %>%
  ungroup()

# Create visualization
p1 <- ggplot(tax_index, aes(x = year, y = index, color = district)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 3) +
  geom_hline(yintercept = 100, linetype = "dashed", alpha = 0.5) +
  scale_y_continuous(
    labels = function(x) paste0(x, "%"),
    limits = c(95, 135),
    breaks = seq(100, 130, 10)
  ) +
  scale_x_continuous(breaks = c(2022, 2023, 2024)) +
  scale_color_manual(
    values = c("Bellbrook" = "#a7b1b7", "Cedarville" = "#ba0c2f"),
    name = "School District"
  ) +
  labs(
    title = "How HB 920 Affected Two Greene County Homes",
    subtitle = "Property tax index: 2022 = 100 | Both properties reappraised in 2023",
    x = "Tax Year",
    y = "Property Tax Index",
    caption = "Source: Greene County Auditor property records\nBellbrook (above 20-mill floor) protected by HB 920 reduction factors\nCedarville (at 20-mill floor) saw full impact of reappraisal"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(color = "gray30", size = 11),
    legend.position = "right",
    panel.grid.minor = element_blank(),
    plot.caption = element_text(hjust = 0, size = 9, color = "gray50")
  )

ggsave("output/greene_county_tax_comparison.png",
       p1, width = 10, height = 6, dpi = 300, bg = "white")

cat("\n✓ Greene County comparison chart saved\n")
cat("\nAll outputs saved to output/\n")
cat("Analysis complete!\n")
