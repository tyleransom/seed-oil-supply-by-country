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
# Harmonize each series via growth-rate backcasting (chain-link splice)
#-------------------------------------------------------------------------------
# The previous approach added a constant level shift, mean(New - Old) over the
# 2010-2013 overlap, to every pre-2014 Old value. Because seed-oil consumption
# grew several-fold over 1961-2013, that constant absolute offset (estimated at
# high modern levels) drove early-year values negative -- e.g. Canada 1961.
#
# Instead, anchor each series to the NEW methodology's level wherever New exists
# and extend backward using the OLD series' own growth rates. For each
# Area x Element x Item, with anchor = earliest year having New present and
# Old > 0, the closed form is:
#
#     harmonized_t = New[anchor] * Old_t / Old[anchor]      (for t < anchor)
#     harmonized_t = New_t                                  (wherever New exists)
#
# This is continuous at the anchor, reproduces the old series' year-over-year
# growth, and cannot go negative when Old >= 0. It divides only by the fixed,
# strictly-positive Old[anchor], so interior zeros in Old yield a clean 0 for
# that year rather than propagating NaN (the failure mode of step-by-step
# chaining), and no New/Old division ever runs away on a near-zero denominator.
backcast <- function(Year, Old, New) {
    ok <- !is.na(New) & !is.na(Old) & Old > 0
    if (!any(ok)) return(New)          # no usable overlap link: keep New, leave pre-period NA
    anchor <- min(Year[ok])
    newA <- New[match(anchor, Year)]
    oldA <- Old[match(anchor, Year)]
    h <- New
    fill <- is.na(New) & !is.na(Old)   # years the new methodology does not cover (pre-period)
    h[fill] <- newA * Old[fill] / oldA
    h
}

df <- df %>%
    group_by(Area, `Element Code`, `Item Code (FBS)`) %>%
    arrange(Year, .by_group = TRUE) %>%
    mutate(harmonized = backcast(Year, Old, New)) %>%
    ungroup()

# Aggregate (used by the diagnostic plots below)
dfagg <- df %>%
    group_by(Area, Year, Element, `Element Code`) %>%
    summarise(Old = sum(Old, na.rm = TRUE),
              New = sum(New, na.rm = TRUE),
              harmonized = sum(harmonized, na.rm = TRUE), .groups = "drop") %>%
    mutate(Old = ifelse(Old == 0, NA, Old),
           New = ifelse(New == 0, NA, New))

# Sanity check: harmonized food supply can never be negative
n_neg <- sum(df$harmonized < 0, na.rm = TRUE)
if (n_neg > 0) warning(sprintf("%d negative harmonized values remain", n_neg)) else
    message("Harmonization OK: no negative values")

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
