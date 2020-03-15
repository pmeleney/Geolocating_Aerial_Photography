###############################################################################
# Purpose of script:
# 1) Combine granular land cover classifications into groups, e.g., combine all
# developed classes into a single 'developed' land cover classifications.
#
# 2) Summarize the land cover classification proportions for each geolocation 
# into a single "predominant class" field. If the top 2 most populated land 
# classes are sufficiently close together, they are combined into a hybrid 
# field, e.g., Cultivated_Developed.

geolocations <- data.table::fread(
  path.classes, 
  sep = ',', 
  quote = FALSE, 
  stringsAsFactors = FALSE
)

# The following land cover groupings are manually copied from the following:
#    https://www.mrlc.gov/data/legends/national-land-cover-database-2016-nlcd2016-legend
nlcdClassLookup <- data.table::data.table(
  sub_class = levels.nlcd,
  class = c(
    'Unclassified',
    'Water',
    'Water',
    'Developed',
    'Developed',
    'Developed',
    'Developed',
    'Barren',
    'Forest',
    'Forest',
    'Forest',
    'Shrubland',
    'Shrubland',
    'Herbaceous',
    'Herbaceous',
    'Herbaceous',
    'Herbaceous',
    'Cultivated',
    'Cultivated',
    'Wetlands',
    'Wetlands'
  ),
  key = 'sub_class'
)

# Melt the land cover proportions by geolocation
geolocations.subclassMelt <- data.table::melt(
  geolocations, 
  id.vars = c('FlightID', 'OBJECTID', 'Frame'), 
  measure.vars = levels.nlcd, 
  value.name = 'Class_Pct', 
  variable.name = 'Sub_Class'
)

# Append grouped version of land covers
geolocations.subclassMelt[
  nlcdClassLookup
  , on = .(Sub_Class = sub_class)
  , Class := i.class
]

# Find predominant land cover for each geolocation
geolocations.class <- data.table::dcast(
    geolocations.subclassMelt[
    , .(
      # Sum up land cover proportions by coarse groupings
      Class_Pct = sum(Class_Pct)
    )
    , keyby = .(FlightID, OBJECTID, Frame, Class)
  ][
    # Rank each land cover proportion total by geolocation
    , Class_Pct_Rank := data.table::frank(
      -Class_Pct, 
      ties.method = 'dense'
    )
    , by = .(FlightID, OBJECTID, Frame)
  ][
    # Calculate the difference between top 2 ranked land cover proportion sums
    , Class_Pct_Diff_Top2 := .SD[
      Class_Pct_Rank <= 2
      , .(max(Class_Pct) - min(Class_Pct))
    ]
    , by = .(FlightID, OBJECTID, Frame)
  ][
    # In the rare case that the top two ranked land cover proportion sums are
    # within 20% of each, e.g., rank 1 has 60% and rank 2 has 40%, concatenate
    # these land covers in alphabetical order for each geolocation.
    , Predominant_Class := ifelse(
      Class_Pct_Diff_Top2 < 0.2, 
      .SD[
        Class_Pct_Rank <= 2
      ][
        order(Class)
        , paste(Class, collapse = '_')
      ],
      # Otherwise, give the land cover with largest proportion sum.
      #
      # Note: The following still concatenates land cover groupings even though
      # 1 land cover should returned for each geolocation. This extra 
      # functionality is used for the corner case where a geolocation has
      # two land covers with exactly equal land cover proportions, and so its
      # rank 1 includes 2 land covers, which are then concatenated in 
      # alphabetical order.
      .SD[
        Class_Pct_Rank == 1
      ][
        order(Class)
        , paste(Class, collapse = '_')
      ]
    )
    , by = .(FlightID, OBJECTID, Frame)
  ][],
  FlightID + OBJECTID + Frame + Predominant_Class ~ Class, 
  value.var = 'Class_Pct'
)

# Export findings
data.table::fwrite(
  geolocations.class,
  file = path.predominant_class,
  row.names = FALSE, 
  quote = FALSE
)
