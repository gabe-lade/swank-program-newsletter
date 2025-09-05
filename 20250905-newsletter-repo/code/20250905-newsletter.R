# Ohio Rural-Urban Classification Analysis (2000-2020)
# Based on Census Bureau housing unit density criteria
rm(list = ls())

library(tidyverse)
library(tidycensus)
library(sf)
library(tigris)
library(tmap)
library(patchwork)
library(units)
library(leaflet)
library(htmlwidgets)

# Set options
# To apply for a Census API key, visit: https://api.census.gov/data/key_signup.html
options(tigris_use_cache = TRUE)
census_api_key("INSERT API HERE") 

### Downloading housing and population variables

## 2000 census  
vars_2000 <- load_variables(2000, "sf1", cache = TRUE)
hvars_2000 <- vars_2000 %>% 
  filter(str_detect(concept, "HOUSING|UNITS"))
pvars_2000 <- vars_2000 %>%
  filter(str_detect(concept, "POPULATION"))
oh_2000 <- get_decennial(
  geography = "block",
  variables = c(housing_units = "H001001", population = "P001001", urban_pop = "P002002", rural_pop= "P002005"),
  state = "OH",
  county = NULL,
  year = 2000,
  geometry = TRUE,
  cache_table = TRUE
) %>%
  pivot_wider(names_from = variable, values_from = value) 

## 2010 census 
vars_2010 <- load_variables(2010, "sf1", cache = TRUE)
hvars_2010 <- vars_2010 %>% 
  filter(str_detect(concept, "HOUSING|UNITS"))
pvars_2010 <- vars_2010 %>%
  filter(str_detect(concept, "POPULATION"))
# Get Ohio county codes
ohio_counties <- fips_codes %>%
  filter(state == "OH") %>%
  pull(county_code)
# Function to get blocks for one county (for some reason can't pull entire state)
get_county_blocks <- function(county_code) {
    get_decennial(
      geography = "block",
      variables = c(housing_units = "H003001", population = "P001001", urban_pop="P002002", rural_pop="P002005"),
      state = "OH",
      county = county_code,  # Specify the county
      year = 2010,
      geometry = TRUE,
      cache_table = TRUE
    ) %>%
      pivot_wider(names_from = variable, values_from = value)
}
# Get blocks for all Ohio counties and combine 
oh_2010_list <- map(ohio_counties, get_county_blocks)
oh_2010_list <- oh_2010_list[!map_lgl(oh_2010_list, is.null)]
oh_2010 <- bind_rows(oh_2010_list)

##2020 census 
vars_2020 <- load_variables(2020, "dhc", cache = TRUE)
hvars_2020 <- vars_2020 %>% 
  filter(str_detect(concept, "HOUSING|UNITS"))
pvars_2020 <- vars_2020 %>%
  filter(str_detect(concept, "RURAL"))
oh_2020 <- get_decennial(
  geography = "block",
  variables = c(housing_units = "H1_001N", population = "P1_001N", urban_pop="P2_002N", rural_pop="P2_003N"),
  state = "OH",
  county = NULL,
  year = 2020,
  geometry = TRUE,
  cache_table = TRUE
) %>%
  pivot_wider(names_from = variable, values_from = value)
rm(hvars_2000, hvars_2010, hvars_2020, oh_2010_list, pvars_2000, pvars_2010, 
   pvars_2020, vars_2000, vars_2010, vars_2020)


###Interpolating 2000 and 2020 blocks to 2010 census blocks

## 2000 to 2010 crosswalk 
ohio_crosswalk_2000 <- read_csv("data/nhgis_blk2000_blk2010_39.csv")
ohio_crosswalk_2000$blk2000ge <- as.character(ohio_crosswalk_2000$blk2000ge)
ohio_crosswalk_2000$blk2010ge <- as.character(ohio_crosswalk_2000$blk2010ge)
oh_2000$blk2000ge <- oh_2000$GEOID
oh_2000_no_geom <- oh_2000 %>% st_drop_geometry()
oh_2000_int <- ohio_crosswalk_2000 %>%
  left_join(oh_2000_no_geom, by = "blk2000ge")
rm(oh_2000_no_geom)
# Apply weights and aggregate to 2010 blocks
oh_2000_int <- oh_2000_int %>%
  mutate(
    # Apply weights to get estimated values for 2010 block boundaries
    pop_2000_weighted = population * weight,
    housing_2000_weighted = housing_units * weight,
    pop_2000_r_weighted=rural_pop * weight, 
    pop_2000_u_weighted=urban_pop * weight
  ) %>%
  # Aggregate to 2010 block level
  group_by(blk2010ge) %>%
  summarise(
    # Sum up all the weighted contributions to each 2010 block
    population_2000_int = sum(pop_2000_weighted, na.rm = TRUE),
    pop_2000_r_int = sum(pop_2000_r_weighted, na.rm = TRUE),
    pop_2000_u_int = sum(pop_2000_u_weighted, na.rm = TRUE),
    housing_2000_int = sum(housing_2000_weighted, na.rm = TRUE),
    # Keep track of how many 2000 blocks contributed
    source_blocks_2000 = n(),
    # Sum of weights 
    total_weight = sum(weight, na.rm = TRUE),
    .groups = 'drop'
  ) 
# Add geometry back from 2010 data
oh_2010$blk2010ge <- oh_2010$GEOID
oh_2000_int <- oh_2010 %>%
  select(blk2010ge, geometry) %>%  # Keep only GEOID and geometry from 2010
  left_join(oh_2000_int, by = "blk2010ge")
rm(ohio_crosswalk_2000)

## 2020 to 2010 crosswalk 
ohio_crosswalk_2020 <- read_csv("data/nhgis_blk2020_blk2010_39.csv")
ohio_crosswalk_2020$blk2020ge <- as.character(ohio_crosswalk_2020$blk2020ge)
ohio_crosswalk_2020$blk2010ge <- as.character(ohio_crosswalk_2020$blk2010ge)
oh_2020$blk2020ge <- oh_2020$GEOID
oh_2020_no_geom <- oh_2020 %>% st_drop_geometry()
oh_2020_int <- ohio_crosswalk_2020 %>%
  left_join(oh_2020_no_geom, by = "blk2020ge")
rm(oh_2020_no_geom)
# Apply weights and aggregate to 2010 blocks
oh_2020_int <- oh_2020_int %>%
  mutate(
    # Apply weights to get estimated values for 2010 block boundaries
    pop_2020_weighted = population * weight,
    housing_2020_weighted = housing_units * weight
  ) %>%
  # Aggregate to 2010 block level
  group_by(blk2010ge) %>%
  summarise(
    # Sum up all the weighted contributions to each 2010 block
    population_2020_int = sum(pop_2020_weighted, na.rm = TRUE),
    housing_2020_int = sum(housing_2020_weighted, na.rm = TRUE),
    # Keep track of how many 2000 blocks contributed
    source_blocks_2020 = n(),
    # Sum of weights 
    total_weight = sum(weight, na.rm = TRUE),
    .groups = 'drop'
  ) 
# Add geometry back from 2010 data
oh_2020_int <- oh_2010 %>%
  select(blk2010ge, geometry) %>%  # Keep only GEOID and geometry from 2010
  left_join(oh_2020_int, by = "blk2010ge")
rm(ohio_crosswalk_2020)


### Calculate area and housing density

## 2000 data
oh_2000_int <- oh_2000_int %>%
  mutate(
    # Calculate area in square miles
    area_sq_miles = as.numeric(st_area(geometry) / 2589988.11), # Convert m² to mi²
    # Calculate housing units per square mile for interpolated 2000 data
    housing_density_2000 = ifelse(area_sq_miles > 0, 
                                  housing_2000_int / area_sq_miles, 0),
    # Clean infinite/NaN values
    housing_density_2000 = ifelse(is.infinite(housing_density_2000) | 
                                    is.nan(housing_density_2000), 0, housing_density_2000)
  )

## 2010 data
oh_2010 <- oh_2010 %>%
  mutate(
    # Calculate area in square miles
    area_sq_miles = as.numeric(st_area(geometry) / 2589988.11), # Convert m² to mi²
    # Calculate housing units per square mile for interpolated 2000 data
    housing_density_2010 = ifelse(area_sq_miles > 0, 
                                  housing_units / area_sq_miles, 0),
    # Clean infinite/NaN values
    housing_density_2010 = ifelse(is.infinite(housing_density_2010) | 
                                    is.nan(housing_density_2010), 0, housing_density_2010)
  )

## 2020 data
oh_2020_int <- oh_2020_int %>%
  mutate(
    # Calculate area in square miles
    area_sq_miles = as.numeric(st_area(geometry) / 2589988.11), # Convert m² to mi²
    # Calculate housing units per square mile for interpolated 2000 data
    housing_density_2020 = ifelse(area_sq_miles > 0, 
                                  housing_2020_int / area_sq_miles, 0),
    # Clean infinite/NaN values
    housing_density_2020 = ifelse(is.infinite(housing_density_2020) | 
                                    is.nan(housing_density_2020), 0, housing_density_2020)
  )


### Create urban/rural classification based on housing density 

## 2000 data
oh_2000_int <- oh_2000_int %>%
  mutate(
    urban_rural_2000 = case_when(
      housing_density_2000 >= 425 ~ "Urban Core",
      housing_density_2000 >= 200 ~ "Urban Peripheral", 
      TRUE ~ "Rural"
    ),
    # Convert to factor with specific order for mapping
    urban_rural_2000 = factor(urban_rural_2000, 
                               levels = c("Urban Core", "Urban Peripheral", "Rural"))
  )

## 2010 data
oh_2010 <- oh_2010 %>%
  mutate(
    urban_rural_2010 = case_when(
      housing_density_2010 >= 425 ~ "Urban Core",
      housing_density_2010 >= 200 ~ "Urban Peripheral", 
      TRUE ~ "Rural"
    ),
    # Convert to factor with specific order for mapping
    urban_rural_2010 = factor(urban_rural_2010, 
                               levels = c("Urban Core", "Urban Peripheral", "Rural"))
  )

## 2020 data
oh_2020_int <- oh_2020_int %>%
  mutate(
    urban_rural_2020 = case_when(
      housing_density_2020 >= 425 ~ "Urban Core",
      housing_density_2020 >= 200 ~ "Urban Peripheral", 
      TRUE ~ "Rural"
    ),
    # Convert to factor with specific order for mapping
    urban_rural_2020 = factor(urban_rural_2020, 
                               levels = c("Urban Core", "Urban Peripheral", "Rural"))
  )


## Create joint Ohio dataframe (2010 census blocks)
oh_join <- oh_2010 %>%
  select(blk2010ge, geometry, housing_density_2010, urban_rural_2010) %>%
  left_join(
    oh_2000_int %>% st_drop_geometry() %>%
      select(blk2010ge, housing_density_2000, urban_rural_2000),
    by = "blk2010ge"
  ) %>%
  left_join(
    oh_2020_int %>% st_drop_geometry() %>%
      select(blk2010ge, housing_density_2020, urban_rural_2020),
    by = "blk2010ge"
  ) 
rm(oh_2000, oh_2000_int, oh_2010, oh_2020, oh_2020_int)


## Calculate rural to urban changes
oh_join <- oh_join %>%
  mutate(
    rural_change_2010 = case_when(
      urban_rural_2000 == "Rural" & urban_rural_2010 %in% c("Urban Core", "Urban Peripheral") ~ "Rural to Urban",
      TRUE ~ "No Change"
    ),
    rural_change_2020 = case_when(
      urban_rural_2010 == "Rural" & urban_rural_2020 %in% c("Urban Core", "Urban Peripheral") ~ "Rural to Urban", 
      TRUE ~ "No Change"
    )
  )



### Creating Maps

# Get Ohio counties 
ohio_counties_map <- counties(state = "OH", cb = TRUE, year = 2010) %>%
  st_transform(4326)

## Map 1 - 2020 Urban Areas (interactive html)

# Extracting urban areas only
oh_2020_urban <- oh_join %>%
  filter(urban_rural_2020 %in% c("Urban Core", "Urban Peripheral")) %>%
  st_transform(4326) %>%
  st_simplify(dTolerance = 0.001) %>%
  mutate(
    popup_text = paste0(
      "<b>Block:</b> ", blk2010ge, "<br>",
      "<b>2020 Classification:</b> ", urban_rural_2020, "<br>",
      "<b>Housing Density:</b> ", round(housing_density_2020, 1), " units/sq mi"
    )
  )

# Create the three-year comparison map
map1_urban_areas <- leaflet() %>%
  addProviderTiles(providers$CartoDB.Positron) %>%
  # Add 2020 urban areas
  addPolygons(
    data = oh_2020_urban,
    fillColor = ~ifelse(urban_rural_2020 == "Urban Core", "#ba0c2f", "#a7b1b7"),
    fillOpacity = 0.7,
    color = "white", 
    weight = 0.5,
    popup = ~popup_text,
    group = "2020 Urban Areas"
  ) %>%
  # Add county boundaries
  addPolygons(
    data = ohio_counties_map,
    fillColor = "transparent",
    color = "#d3d3d3", 
    weight = 1.5,
    opacity = 0.8,
    fillOpacity = 0,
    popup = ~paste0("<b>", NAME, " County</b>"),
    group = "County Boundaries"
  ) %>%
    addLegend(
    position = "bottomright",
    colors = c("#ba0c2f", "#a7b1b7"),
    labels = c("Urban Core", "Urban Peripheral"),
    title = "Classification"
  ) %>%
  setView(lng = -82.5, lat = 40.2, zoom = 7) 
  
 
# Save first map
saveWidget(map1_urban_areas, "figures/map1_urban_areas", selfcontained = TRUE)


## Map 2 - 2020 Urban Areas (static map)
ohio_counties_static <- counties(state = "OH", cb = TRUE, year = 2010)
map2_urban_areas <- ggplot() +
  geom_sf(data = oh_join, 
          aes(fill = urban_rural_2020), 
          color = NA, size = 0) +
  geom_sf(data = ohio_counties_static, 
          fill = "transparent", 
          color = "#d3d3d3", 
          size = 0.3) +
  scale_fill_manual(
    values = c(
      "Urban Core" = "#ba0c2f",
      "Urban Peripheral" = "#a7b1b7", 
      "Rural" = "#ffffff"
    ),
    name = "Classification",
    drop = FALSE
  ) +
  labs(
    title = "Ohio Urban-Rural Classification (2020)",
    subtitle = "≥425 units/sq mi = Urban Core, ≥200 units/sq mi = Urban Peripheral",
    caption = "Data: 2020 Census (2010 block boundaries)"
  ) +
  theme_void() +
  theme(
    plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
    plot.subtitle = element_text(hjust = 0.5, size = 10),
    plot.caption = element_text(hjust = 0.5, size = 8),
    legend.position = "bottom",
    legend.title = element_text(face = "bold"),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA),
    legend.key.size = unit(0.5, "cm")
  )
ggsave("figures/map2_urban_areas.png", map2_urban_areas, 
       width = 10, height = 8, dpi = 500, bg = "white")



## Map 3 - Rural to Urban Changes (interactive)
oh_changes <- oh_join %>%
  filter(rural_change_2010 == "Rural to Urban" | rural_change_2020 == "Rural to Urban") %>%
  st_transform(4326) %>%
  st_simplify(dTolerance = 0.001) %>%
  mutate(
    change_period = case_when(
      rural_change_2010 == "Rural to Urban" & rural_change_2020 == "Rural to Urban" ~ "Both Periods",
      rural_change_2010 == "Rural to Urban" ~ "2000-2010 Only", 
      rural_change_2020 == "Rural to Urban" ~ "2010-2020 Only",
      TRUE ~ "No Change"
    ),
    popup_text = paste0(
      "<b>Block:</b> ", blk2010ge, "<br>",
      "<b>Change Period:</b> ", change_period, "<br>",
      "<b>2000 Class:</b> ", urban_rural_2000, "<br>",
      "<b>2010 Class:</b> ", urban_rural_2010, "<br>",
      "<b>2020 Class:</b> ", urban_rural_2020, "<br>",
      "<b>2010 Density:</b> ", round(housing_density_2010, 1), "<br>",
      "<b>2020 Density:</b> ", round(housing_density_2020, 1)
    )
  )
change_color_pal <- colorFactor(
  palette = c("#ff6b35", "#004e89"),
  domain = c("2000-2010", "2010-2020"),
  na.color = "transparent"
)

# Create change map with corrected color mapping
map3_urban_conversions <- leaflet(oh_changes) %>%
  addProviderTiles(providers$CartoDB.Positron) %>%
  
  addPolygons(
    fillColor = ~change_color_pal(change_period),  # Use the color palette function
    fillOpacity = 0.8,
    color = "white",
    weight = 0.5,
    popup = ~popup_text,
    group = "Rural to Urban Changes"
  ) %>%
  
  # Add county boundaries
  addPolygons(
    data = ohio_counties_map,
    fillColor = "transparent",
    color = "#d3d3d3",
    weight = 1.5,
    opacity = 0.8, 
    fillOpacity = 0,
    popup = ~paste0("<b>", NAME, " County</b>"),
    group = "County Boundaries"
  ) %>%
  
  addLayersControl(
    overlayGroups = c("Rural to Urban Changes", "County Boundaries"),
    options = layersControlOptions(collapsed = FALSE)
  ) %>%
  
  # Use the palette function for the legend too
  addLegend(
    position = "bottomright",
    pal = change_color_pal,
    values = ~change_period,
    title = "Rural to Urban Changes",
    opacity = 1
  ) %>%
  
  setView(lng = -82.5, lat = 40.2, zoom = 7) %>%
  
  addControl(
    html = "<h3>Ohio Rural to Urban Changes (2000-2020)</h3>
            <p>Census blocks that changed from rural to urban classification</p>",
    position = "topright"
  )

# Save the corrected map
saveWidget(map3_urban_conversions, "figures/map3_urban_conversions.html", selfcontained = TRUE)


## Map 4 - Rural to Urban Changes (static)
oh_join_changes <- oh_join %>%
  mutate(
    change_2010 = case_when(
      rural_change_2010 == "Rural to Urban" ~ "Rural to Urban (2000-2010)",
      TRUE ~ "No Change"
    ),
    change_2020 = case_when(  
      rural_change_2020 == "Rural to Urban" ~ "Rural to Urban (2010-2020)",
      TRUE ~ "No Change"
    ),
    # Combined changes for single map
    combined_changes = case_when(
      rural_change_2010 == "Rural to Urban" & rural_change_2020 == "Rural to Urban" ~ "Changed Both Periods",
      rural_change_2010 == "Rural to Urban" ~ "Changed 2000-2010 Only",
      rural_change_2020 == "Rural to Urban" ~ "Changed 2010-2020 Only", 
      TRUE ~ "No Change"
    )
  )

map4_urban_conversions <- ggplot() +
  # Show unchanged areas in light gray
  geom_sf(data = oh_join_changes %>% filter(combined_changes == "No Change"), 
          fill = "#ffffff", color = NA, size = 0) +
  # Show changes with different colors
  geom_sf(data = oh_join_changes %>% filter(combined_changes != "No Change"), 
          aes(fill = combined_changes), color = NA, size = 0) +
  # Add county boundaries
  geom_sf(data = ohio_counties_static, 
          fill = "transparent", 
          color = "#666666", 
          size = 0.4) +
  scale_fill_manual(
    values = c(
      "Changed 2000-2010 Only" = "#ff6b35",    # Orange
      "Changed 2010-2020 Only" = "#004e89",    # Blue
      "Changed Both Periods" = "#7209b7"       # Purple
    ),
    name = "Change Period"
  ) +
  labs(
    title = "Rural to Urban Changes (2000-2020)",
    subtitle = "Areas that changed from rural to urban classification by time period",
    caption = "White areas show no change from rural classification"
  ) +
  theme_void() +
  theme(
    plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
    plot.subtitle = element_text(hjust = 0.5, size = 11),
    plot.caption = element_text(hjust = 0.5, size = 8),
    legend.position = "bottom",
    legend.title = element_text(face = "bold"),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA),
    legend.key.size = unit(0.5, "cm")
  )

# Save change maps
ggsave("figures/map4_urban_conversions.png", map4_urban_conversions,
       width = 10, height = 8, dpi = 300, bg = "white")
