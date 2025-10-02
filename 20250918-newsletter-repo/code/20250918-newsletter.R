# Ohio Urbanization Analysis (2000-2020)
rm(list = ls())

library(tidyverse)
library(sf)
library(tigris)
library(viridis) 
library(ggplot2)

oh_join <- readRDS("data/oh_join.rds")

######
# AGGREGATE CHANGE STATISTICS
change_analysis <- oh_join %>%
  st_drop_geometry() %>%
  # Calculate area in square miles for each block
  mutate(
    area_sq_miles = as.numeric(st_area(oh_join$geometry) / 2589988.11)
  ) %>%
  summarise(
    # Block counts
    total_blocks = n(),
    changed_2000_2010 = sum(rural_change_2010 == "Rural to Urban", na.rm = TRUE),
    changed_2010_2020 = sum(rural_change_2020 == "Rural to Urban", na.rm = TRUE),
    changed_both_periods = sum(rural_change_2010 == "Rural to Urban" & 
                                 rural_change_2020 == "Rural to Urban", na.rm = TRUE),
    
    # Land area calculations (in square miles)
    total_area_sq_miles = sum(area_sq_miles, na.rm = TRUE),
    area_changed_2000_2010 = sum(area_sq_miles[rural_change_2010 == "Rural to Urban"], na.rm = TRUE),
    area_changed_2010_2020 = sum(area_sq_miles[rural_change_2020 == "Rural to Urban"], na.rm = TRUE),
    area_changed_both = sum(area_sq_miles[rural_change_2010 == "Rural to Urban" & 
                                            rural_change_2020 == "Rural to Urban"], na.rm = TRUE),
    
    # Unique area converted (avoiding double counting)
    total_unique_area_converted = sum(area_sq_miles[rural_change_2010 == "Rural to Urban" | 
                                                      rural_change_2020 == "Rural to Urban"], na.rm = TRUE),
    
    # Calculate percentages
    pct_blocks_changed_2000_2010 = round(changed_2000_2010 / total_blocks * 100, 2),
    pct_blocks_changed_2010_2020 = round(changed_2010_2020 / total_blocks * 100, 2),
    pct_area_changed_2000_2010 = round(area_changed_2000_2010 / total_area_sq_miles * 100, 2),
    pct_area_changed_2010_2020 = round(area_changed_2010_2020 / total_area_sq_miles * 100, 2)
  )

# Print summary
cat("=== OHIO RURAL TO URBAN CONVERSION ANALYSIS ===\n\n")

cat("BLOCK COUNT CHANGES:\n")
cat("- Total census blocks:", format(change_analysis$total_blocks, big.mark = ","), "\n")
cat("- Changed 2000-2010:", format(change_analysis$changed_2000_2010, big.mark = ","), 
    "blocks (", change_analysis$pct_blocks_changed_2000_2010, "%)\n")
cat("- Changed 2010-2020:", format(change_analysis$changed_2010_2020, big.mark = ","), 
    "blocks (", change_analysis$pct_blocks_changed_2010_2020, "%)\n")
cat("- Changed both periods:", format(change_analysis$changed_both_periods, big.mark = ","), "blocks\n\n")

cat("LAND AREA CONVERSIONS:\n")
cat("- Total Ohio area:", format(round(change_analysis$total_area_sq_miles, 0), big.mark = ","), "sq miles\n")
cat("- Converted 2000-2010:", format(round(change_analysis$area_changed_2000_2010, 1), big.mark = ","), 
    "sq miles (", change_analysis$pct_area_changed_2000_2010, "%)\n")
cat("- Converted 2010-2020:", format(round(change_analysis$area_changed_2010_2020, 1), big.mark = ","), 
    "sq miles (", change_analysis$pct_area_changed_2010_2020, "%)\n")
cat("- Total unique area converted:", format(round(change_analysis$total_unique_area_converted, 1), big.mark = ","), "sq miles\n\n")



######
# COUNTY ANALYSIS

# Extract county FIPS from block GEOID and get county names
oh_join_with_county <- oh_join %>%
  mutate(
    # Extract county FIPS (characters 3-5 of block GEOID)
    county_fips = str_sub(blk2010ge, 3, 5),
    # Calculate area in square miles for each block
    area_sq_miles = as.numeric(st_area(geometry) / 2589988.11),
    # Create a combined change indicator
    changed_any_period = rural_change_2010 == "Rural to Urban" | rural_change_2020 == "Rural to Urban"
  )

# Get Ohio county names using tigris
ohio_counties <- counties(state = "OH", year = 2010) %>%
  st_drop_geometry() %>%
  select(COUNTYFP10, NAME10) %>%
  rename(county_fips = COUNTYFP10, county_name = NAME10)

# Merge county names with the data
oh_join_with_county <- oh_join_with_county %>%
  st_drop_geometry() %>%
  left_join(ohio_counties, by = "county_fips")

# Calculate county-level statistics
county_analysis <- oh_join_with_county %>%
  group_by(county_fips, county_name) %>%
  summarise(
    # Total blocks and area
    total_blocks = n(),
    total_area_sq_miles = sum(area_sq_miles, na.rm = TRUE),
    
    # Area changes by period
    area_changed_2000_2010 = sum(area_sq_miles[rural_change_2010 == "Rural to Urban"], na.rm = TRUE),
    area_changed_2010_2020 = sum(area_sq_miles[rural_change_2020 == "Rural to Urban"], na.rm = TRUE),
    area_changed_both = sum(area_sq_miles[rural_change_2010 == "Rural to Urban" & 
                                            rural_change_2020 == "Rural to Urban"], na.rm = TRUE),
    area_changed_total = sum(area_sq_miles[changed_any_period], na.rm = TRUE),

    
    .groups = 'drop'
  ) %>%
  # Arrange by total area changed (descending)
  arrange(desc(area_changed_total))

# Display top 10 counties by total rural-to-urban conversion
cat("=== TOP 10 OHIO COUNTIES BY RURAL-TO-URBAN LAND CONVERSION (2000-2020) ===\n\n")

top_10_counties <- county_analysis %>%
  slice_head(n = 10) %>%
  select(county_name, area_changed_total, area_changed_2000_2010, area_changed_2010_2020)

print(top_10_counties)





# Get Ohio county geometries
ohio_counties_geo <- counties(state = "OH", year = 2010, cb = TRUE) %>%
  select(COUNTYFP, NAME, geometry) %>%
  rename(county_fips = COUNTYFP, county_name = NAME)

# Merge county analysis results with geometries
county_map_data <- ohio_counties_geo %>%
  left_join(county_analysis, by = c("county_fips", "county_name")) %>%
  # Handle any counties with no data (should be rare)
  mutate(
    area_changed_total = ifelse(is.na(area_changed_total), 0, area_changed_total),
  )

# Create the heat map
county_heatmap <- ggplot(county_map_data) +
  geom_sf(aes(fill = area_changed_total), color = "white", size = 0.3) +
  scale_fill_viridis_c(
    name = "Land Converted\n(sq miles)",
    option = "plasma",  # Colorblind-friendly palette
    trans = "sqrt",     # Square root transformation for better distribution
    labels = function(x) round(x, 1),
    guide = guide_colorbar(
      title.position = "top",
      title.hjust = 0.5,
      barwidth = 15,
      barheight = 1
    )
  ) +
  labs(
    title = "Rural to Urban Land Conversion by County (2000-2020)",
    subtitle = "Ohio counties showing total square miles converted from rural to urban areas",
    caption = "Data: U.S. Census Bureau | Colors use square root scale for better visualization"
  ) +
  theme_void() +
  theme(
    plot.title = element_text(hjust = 0.5, size = 16, face = "bold"),
    plot.subtitle = element_text(hjust = 0.5, size = 12),
    plot.caption = element_text(hjust = 0.5, size = 9),
    legend.position = "bottom",
    legend.title = element_text(size = 11, face = "bold"),
    legend.text = element_text(size = 9),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA)
  )

# Add county labels for top counties
top_5_counties_geo <- county_map_data %>%
  slice_max(area_changed_total, n = 25) %>%
  st_centroid() %>%
  mutate(
    coords = st_coordinates(.),
    X = coords[,1],
    Y = coords[,2]
  ) %>%
  st_drop_geometry()

# Labels
county_heatmap_labeled <- county_heatmap +
  geom_text(data = top_5_counties_geo, 
            aes(x = X, y = Y, label = county_name),
            color = "white", fontface = "bold", size = 3.5,
            check_overlap = TRUE)

ggsave("figures/ohio_county_conversion.png", county_heatmap_labeled,
       width = 12, height = 9, dpi = 300, bg = "white")
