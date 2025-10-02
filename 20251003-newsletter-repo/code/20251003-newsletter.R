# Ohio Ag Crop Production Value Analysis (2000-2024)
# Note: Identified crops from:
# https://www.nass.usda.gov/Quick_Stats/Ag_Overview/stateOverview.php?state=OHIO
rm(list = ls())

library(rnassqs)
library(dplyr)
library(fredr)
library(ggplot2)
library(scales)
library(purrr)
library(plotly)
library(htmlwidgets)

# Load API keys from config file
source("code/config.R")
nassqs_auth(key = NASS_API_KEY)
fredr_set_key(FRED_API_KEY)

# Define parameters for each commodity
params <- list(
  corn = list(agg_level_desc="state", 
              commodity_desc = "corn", 
              source_desc="survey",
              state_alpha = "oh", 
              short_desc="CORN, GRAIN - PRODUCTION, MEASURED IN $"),
  
  soybeans = list(agg_level_desc="state", 
                  commodity_desc = "soybeans", 
                  source_desc="survey",
                  state_alpha = "oh", 
                  short_desc="SOYBEANS - PRODUCTION, MEASURED IN $"),
  
  hay = list(agg_level_desc="state", 
             commodity_desc = "hay", 
             source_desc="survey",
             state_alpha = "oh", 
             short_desc="HAY - PRODUCTION, MEASURED IN $"),
  
  wheat = list(agg_level_desc="state", 
               commodity_desc = "wheat", 
               source_desc="survey",
               state_alpha = "oh", 
               short_desc="WHEAT - PRODUCTION, MEASURED IN $"),
  
  pumpkins = list(agg_level_desc="state", 
                  commodity_desc = "pumpkins", 
                  source_desc="survey",
                  state_alpha = "oh", 
                  short_desc="PUMPKINS - PRODUCTION, MEASURED IN $"),
  
  oats = list(agg_level_desc="state", 
              commodity_desc = "oats", 
              source_desc="survey",
              state_alpha = "oh", 
              short_desc="OATS - PRODUCTION, MEASURED IN $"),
  
  syrup = list(agg_level_desc="state", 
               commodity_desc = "maple syrup", 
               source_desc="survey",
               state_alpha = "oh", 
               short_desc="MAPLE SYRUP - PRODUCTION, MEASURED IN $")
)

# Function to fetch and process crop data
process_crop_data <- function(param_list) {
  crop_data_list <- lapply(param_list, function(params) {
    data <- nassqs(params)
    data %>%
      filter(year >= 2000) %>%
      select(commodity_desc, year, Value, short_desc) %>%
      rename(prod_val = Value) %>%
      mutate(
        year = as.numeric(year),
        prod_val = as.numeric(gsub(",", "", prod_val))
      )
  })
  
  # Combine all data frames
  do.call(rbind, crop_data_list)
}

# Fetch all crop data
crops <- process_crop_data(params)


# Get CPI data
cpi <- fredr(
  series_id = "CPIAUCSL",
  observation_start = as.Date("2000-01-01"),
  observation_end = as.Date("2024-01-01"),
  frequency = "m"
)

# Process CPI data
cpi_processed <- cpi %>%
  select(date, value) %>%
  rename(cpi = value) %>%
  mutate(
    year = as.numeric(format(date, "%Y")),
    month = as.numeric(format(date, "%m"))
  ) %>%
  filter(month == 1) %>%  # Keep only January values
  select(year, cpi)

# Merge crops with CPI data
crops_final <- crops %>%
  left_join(cpi_processed, by = "year") %>%
  mutate(
    # Get 2024 CPI for adjustment (January 2024)
    cpi_2024 = cpi_processed$cpi[cpi_processed$year == 2024],
    # Adjust to 2024 dollars
    prod_val_real = prod_val * (cpi_2024 / cpi),
    # Clean up commodity names for better display
    commodity_clean = case_when(
      commodity_desc == "CORN" ~ "Corn",
      commodity_desc == "SOYBEANS" ~ "Soybeans", 
      commodity_desc == "HAY" ~ "Hay",
      commodity_desc == "WHEAT" ~ "Wheat",
      commodity_desc == "PUMPKINS" ~ "Pumpkins",
      commodity_desc == "OATS" ~ "Oats",
      commodity_desc == "MAPLE SYRUP" ~ "Maple Syrup",
      TRUE ~ commodity_desc
    )
  ) %>%
  select(commodity_clean, year, prod_val_real) %>%
  rename(commodity = commodity_clean, prod_val = prod_val_real)

# Create stacked area chart - Major crops only with specified order
crops_major <- crops_final %>%
  filter(!commodity %in% c("Maple Syrup", "Oats", "Pumpkins")) %>%
  mutate(commodity = factor(commodity, levels = c("Wheat", "Hay", "Soybeans", "Corn")))

p1 <- ggplot(crops_major, aes(x = year, y = prod_val, fill = commodity)) +
  geom_area(alpha = 0.8, size = 0.5, color = "white") +
  scale_fill_brewer(type = "qual", palette = "Set3", name = "Crop") +
  scale_x_continuous(breaks = seq(2000, 2024, 4)) +
  scale_y_continuous(labels = scales::dollar_format(scale = 1e-6, suffix = "M")) +
  labs(
    title = "Ohio Agricultural Production Value - Major Crops (2000-2024)",
    subtitle = "Corn, soybeans, hay, and wheat - Inflation-adjusted to 2024 dollars",
    x = "Year",
    y = "Production Value (Millions $)",
    caption = "Source: USDA NASS"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 16, face = "bold"),
    plot.subtitle = element_text(size = 12, color = "gray60"),
    legend.position = "right",
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_line(color = "gray90", size = 0.5),
    panel.grid.major.y = element_line(color = "gray90", size = 0.5)
  )

# Create second chart with only the three smallest crops
crops_small <- crops_final %>%
  filter(commodity %in% c("Maple Syrup", "Oats", "Pumpkins"))

p2 <- ggplot(crops_small, aes(x = year, y = prod_val, fill = commodity)) +
  geom_area(alpha = 0.8, size = 0.5, color = "white") +
  scale_fill_brewer(type = "qual", palette = "Set2", name = "Crop") +
  scale_x_continuous(breaks = seq(2000, 2024, 4)) +
  scale_y_continuous(labels = scales::dollar_format(scale = 1e-6, suffix = "M")) +
  labs(
    title = "Ohio Agricultural Production Value - Specialty Crops (2000-2024)",
    subtitle = "Maple syrup, oats, and pumpkins - Inflation-adjusted to 2024 dollars",
    x = "Year",
    y = "Production Value (Millions $)",
    caption = "Source: USDA NASS"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(size = 16, face = "bold"),
    plot.subtitle = element_text(size = 12, color = "gray60"),
    legend.position = "right",
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_line(color = "gray90", size = 0.5),
    panel.grid.major.y = element_line(color = "gray90", size = 0.5)
  )

# Display both static charts
print(p1)
print(p2)

# Save high-quality PNG versions
ggsave("ohio_major_crops.png", plot = p1, width = 12, height = 8, dpi = 300, bg = "white")
ggsave("ohio_specialty_crops.png", plot = p2, width = 12, height = 8, dpi = 300, bg = "white")


# Display summary statistics
cat("Summary of Ohio Crop Production Values (2024 dollars):\n")
crops_final %>%
  group_by(commodity) %>%
  summarise(
    avg_value = mean(prod_val, na.rm = TRUE),
    total_value = sum(prod_val, na.rm = TRUE),
    years_available = n(),
    .groups = 'drop'
  ) %>%
  arrange(desc(avg_value)) %>%
  mutate(
    avg_value = scales::dollar(avg_value, scale = 1e-6, suffix = "M"),
    total_value = scales::dollar(total_value, scale = 1e-6, suffix = "M")
  ) %>%
  print()



##COUNTY MAPS

# Define parameters for each commodity at county level
params_cty <- list(
  corn = list(agg_level_desc="county", 
              commodity_desc = "corn", 
              source_desc="census",
              state_alpha = "oh", 
              year="2022",
              short_desc="CORN, GRAIN - PRODUCTION, MEASURED IN BU"), 
  
  soybeans = list(agg_level_desc="county", 
                  commodity_desc = "soybeans", 
                  source_desc="census",
                  state_alpha = "oh", 
                  year="2022",
                  short_desc="SOYBEANS - PRODUCTION, MEASURED IN BU"),

  hay =list(agg_level_desc="county", 
            source_desc="census",
            state_alpha = "oh", 
            commodity_desc = "hay", 
            short_desc="HAY - PRODUCTION, MEASURED IN TONS", 
            year="2022"), 
  
  wheat = list(agg_level_desc="county", 
               source_desc="census",
               state_alpha = "oh", 
               commodity_desc = "wheat", 
               year="2022", 
               short_desc="WHEAT, WINTER - PRODUCTION, MEASURED IN BU"),
  
  pumpkins = list(agg_level_desc="county", 
                  commodity_desc = "pumpkins", 
                  source_desc="census",
                  state_alpha = "oh", 
                  year="2022", 
                  short_desc="PUMPKINS - ACRES HARVESTED"),
  
  oats = list(agg_level_desc="county", 
              commodity_desc = "oats", 
              source_desc="census",
              state_alpha = "oh", 
              year="2022", 
              short_desc="OATS - PRODUCTION, MEASURED IN BU"),
  
  syrup = list(agg_level_desc="county", 
               commodity_desc = "maple syrup", 
               source_desc="census",
               state_alpha = "oh", 
               year="2022", 
               short_desc="MAPLE SYRUP - PRODUCTION, MEASURED IN GALLONS")
)


# Function to fetch and process crop data
process_crop_data_cty <- function(param_list) {
  crop_data_list <- lapply(param_list, function(params) {
    data <- nassqs(params)
    data %>%
      filter(year >= 2000) %>%
      select(commodity_desc, year, Value, short_desc, state_fips_code, county_code, county_name) %>%
      rename(prod_val = Value) %>%
      mutate(
        year = as.numeric(year),
        prod_val = as.numeric(gsub(",", "", prod_val))
      )
  })
  
  # Combine all data frames
  do.call(rbind, crop_data_list)
}


crops_cty <- process_crop_data_cty(params_cty)


