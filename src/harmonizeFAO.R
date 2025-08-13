library(tidyverse)
library(ggrepel)
library(broom)

#-------------------------------------------------------------------------------
# Data cleaning
#-------------------------------------------------------------------------------
# Read in CSV files
dfpre  <- read_csv("../data/raw/FAOSTAT-1961-2013.csv")
dfpost <- read_csv("../data/raw/FAOSTAT-2010-2022.csv")

# Merge pre- and post- data together
df <- full_join(dfpre, dfpost, by = c("Area","Element Code","Element","Item Code (FBS)","Item","Unit","Year")) %>%
  select(Area, Year, Element, `Element Code`, Item, `Item Code (FBS)`, Old = Value.x, New = Value.y) %>%
  mutate(harmonized = coalesce(New, Old)) %>%
  filter(Item != "Grand Total") #%>%
  ## convert kg to lbs if element code 645
  #mutate(Old = ifelse(`Element Code` == 645, Old * 2.20462, Old),
  #       New = ifelse(`Element Code` == 645, New * 2.20462, New),
  #       harmonized = ifelse(`Element Code` == 645, harmonized * 2.20462, harmonized))


#-------------------------------------------------------------------------------
# Visualize discrepancies by oil type
#-------------------------------------------------------------------------------
# first, define a vector of oil types and their corresponding search patterns
oil_types <- c(
    "Soybean" = "^Soya",
    "Corn" = "^Maiz",
    "Canola" = "^Rape",
    "Cottonseed" = "^Cotton",
    "Sunflowerseed" = "^Sunfl",
    "Peanut" = "^Groundn",
    "Other" = "^Oilcrop"
)

# # Loop through each oil type
# for (oil_name in names(oil_types)) {
#     # Filter data for the current oil type
#     plot_data <- df %>% 
#         filter(`Element Code` == 645 & str_detect(Item, oil_types[oil_name])) %>%
#         tidyr::pivot_longer(cols = c(Old, New), names_to = "Methodology", values_to = "Value")
#     
#     # Create the plot
#     p <- ggplot(plot_data, aes(x = Year, y = Value, linetype = Methodology)) +
#         geom_line(size = 1.05) +
#         geom_text_repel(data = . %>% group_by(Methodology) %>% filter(Year == max(Year)),
#                         aes(label = Methodology),
#                         nudge_x = 2.5,
#                         direction = "y",
#                         hjust = 0,
#                         segment.color = NA,
#                         box.padding = 0.5,
#                         force = 10,
#                         max.overlaps = Inf) +
#         labs(x = "Year",
#              y = "Total Annual Pounds Per Capita") +
#         scale_x_continuous(limits = c(min(plot_data$Year), max(plot_data$Year) + 5)) +
#         theme_minimal() +
#         theme(legend.position = "none")
#     
#     # Save the plot
#     figpath <- "../../../exhibits/figures/"
#     ggsave(filename = paste0(figpath,"fao-methodology-",tolower(oil_name),".eps"), 
#            width = 5, height = 5, dpi = 300)
# }


#-------------------------------------------------------------------------------
# Harmonize aggregated series (across all oil types)
#-------------------------------------------------------------------------------
# Get average difference between 2010-2013 and adjust each series by that in the Old method
adj <- df %>%
    group_by(Area, `Element Code`, `Item Code (FBS)`) %>%
    mutate(diff = New - Old) %>%
    summarize(diff = mean(diff, na.rm = TRUE))

df <- df %>%
    left_join(adj, by = c("Area", "Element Code", "Item Code (FBS)")) %>%
    mutate(harmonized = Old + diff) %>%
    # harmonized should be New if year is 2014 or later
    mutate(harmonized = ifelse(Year >= 2014, New, harmonized))

# Aggregate
dfagg <- df %>%
    group_by(Area, Year, Element, `Element Code`) %>%
    summarise(Old = sum(Old, na.rm = TRUE), 
              New = sum(New, na.rm = TRUE),
              harmonized = sum(harmonized, na.rm = TRUE)) %>%
    mutate(Old = ifelse(Old == 0, NA, Old),
           New = ifelse(New == 0, NA, New),
           harmonized = ifelse(Year >= 2014, NA, harmonized))

# # pounds per capita per year
# ggplot(dfagg %>% filter(`Element Code`==645), aes(x = Year, y = Old, linetype = "Old")) +
#     geom_line() +
#     geom_line(aes(y = New, linetype = "New")) +
#     geom_line(aes(y = harmonized, linetype = "Harmonized Old")) +
#     labs(x = "Year",
#          y = "Total Annual Pounds Per Capita",
#          linetype = "Methodology") +
#     theme_minimal() +
#     theme(legend.position = c(1, 0.1),  # Place legend in the bottom right corner
#           legend.justification = c(1, 0),  # Anchor the legend at the bottom right corner
#           legend.background = element_blank(),  # Optional: make legend background transparent
#           legend.box.background = element_rect(color="white", size=0.5),  # Optional: add a white background to the legend box for better visibility
#           legend.box.margin = margin(6, 6, 6, 6))  # Optional: adjust margin around the legend box
# # Save the plot
# figpath <- "../../../exhibits/figures/"
# ggsave(filename = paste0(figpath,"fao-harmonized-supply.eps"), 
#        width = 5, height = 5, dpi = 300)
# 
# # calories per capita per day
# ggplot(dfagg %>% filter(`Element Code`==664), aes(x = Year, y = Old, linetype = "Old")) +
#     geom_line() +
#     geom_line(aes(y = New, linetype = "New")) +
#     geom_line(aes(y = harmonized, linetype = "Harmonized Old")) +
#     labs(x = "Year",
#          y = "Daily Calories Per Capita",
#          linetype = "Methodology") +
#     theme_minimal() +
#     theme(legend.position = c(1, 0.1),  # Place legend in the bottom right corner
#           legend.justification = c(1, 0),  # Anchor the legend at the bottom right corner
#           legend.background = element_blank(),  # Optional: make legend background transparent
#           legend.box.background = element_rect(color="white", size=0.5),  # Optional: add a white background to the legend box for better visibility
#           legend.box.margin = margin(6, 6, 6, 6))  # Optional: adjust margin around the legend box
# # Save the plot
# figpath <- "../../../exhibits/figures/"
# ggsave(filename = paste0(figpath,"fao-harmonized-energy.eps"), 
#        width = 5, height = 5, dpi = 300)


#-------------------------------------------------------------------------------
# Export the harmonized data
#-------------------------------------------------------------------------------
# Sort data
df <- df %>%
    arrange(Area, `Element Code`, `Item Code (FBS)`, Year)

# Aggregate and save as CSV
df %>%
    group_by(Area, Year, Element, `Element Code`) %>%
    select(-Old, -New) %>%
    summarise(harmonized = sum(harmonized, na.rm = TRUE)) %>%
    write_csv("../data/cleaned/seed-oils-all.csv")

# Aggregate and save as CSV (dropping "other oilcrops oils", "sesameseed oil" and "groundnut oil" categories)
df %>%
    filter(Item != "Oilcrops Oil, Other") %>%
    filter(Item != "Groundnut Oil") %>%
    filter(Item != "Sesameseed Oil") %>%
    group_by(Area, Year, Element, `Element Code`) %>%
    select(-Old, -New) %>%
    summarise(harmonized = sum(harmonized, na.rm = TRUE)) %>%
    write_csv("../data/cleaned/seed-oils-6-largest.csv")
