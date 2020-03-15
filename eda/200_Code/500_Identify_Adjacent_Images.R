###############################################################################
# Purpose of script:
# Order the geolocations for each flight according to spacial adjacency. 
# Although the Frame column tends to denote spacial adjacency well, it does not
# always do so. We need to derive this attribute to ensure a selection of
# geolocations are indeed nearby.

# Import selected geolocations
geolocations <- data.table::fread(
  path.selected_geolocations, 
  sep = ',', 
  quote = FALSE, 
  stringsAsFactors = FALSE
)

# To improve speed, use all processors
data.table::setDTthreads(percent = 100)

###############################################################################
## Identify geolocations with same location

geolocations[
  order(OBJECTID), 
  duplicateLocationRowNum := 1:.N, 
  by = .(Longitude, Latitude)
]

# There are at most duplicates of same location, and there are 58 duplicate 
# pairs.
geolocations[, .N, keyby = .(duplicateLocationRowNum)]

geolocations[
  , duplicateLocationInd := ifelse(
    max(duplicateLocationRowNum) == 2, 
    TRUE, 
    FALSE
  )
  , by = .(Longitude, Latitude)
]

# Determine to what extent duplicate geolocations have different image 
# properties.
geolocations.duplicateStats <- geolocations[
  (duplicateLocationInd)
  , .(
    Pct_Image_Height_Diff = (max(Image_Height) - min(Image_Height)) / 
      max(Image_Height), 
    Pct_Image_Width_Diff = (max(Image_Width) - min(Image_Width)) / 
      max(Image_Width))
  , keyby = .(Longitude, Latitude)
]

# Answer: At worst, image width or height is ~1% different for duplicate
# geolocations.
#
# Conclusion: It's fine to drop 1 duplicate and keep the other without losing
# content.
geolocations.duplicateStats[order(-Pct_Image_Width_Diff)]
geolocations.duplicateStats[order(-Pct_Image_Height_Diff)]

geolocations <- geolocations[duplicateLocationRowNum == 1]

imageDistances <- calculateImageDistances(
  # "Flight pairs" here are flights paired with themselves, in order to 
  # calculate the pairwise distance between geolocations.
  flightPairs = geolocations[
    , .N
    , by = .(
      flightID1 = FlightID,
      flightID2 = FlightID
    )
  ],
  imageGeolocations = geolocations
)

# Use median minimum distance for each flight as reference metric
minimumPairwiseDistances <- imageDistances[
  , .(
    # Calculate minimum distance for each geolocation with all other 
    # geolocations of the same flight.
    Center_Distance.min = min(Center_Distance)
  )
  , by = .(FlightID1, OBJECTID1)
][
  , .(
    # Calculate median & mean minimum pairwise distance for each flight
    Center_Distance.min.median = median(Center_Distance.min),
    Center_Distance.min.mean = mean(Center_Distance.min)
  )
  , keyby = .(FlightID = FlightID1)
]

# Append median minimum distance for each flight, since mean is sensitive to
imageDistances[
  minimumPairwiseDistances
  , on = .(FlightID1 = FlightID)
  , Center_Distance.min.median := i.Center_Distance.min.median
]

# Create rank of Center_Distance_y by sign and absolute value
imageDistances[
  , `:=` (
    Center_Distance_y.sign = sign(Center_Distance_y),
    Center_Distance_x.sign = sign(Center_Distance_x)
  )
][
  Center_Distance <= Center_Distance.min.median * 1.5 &
    Center_Distance_Portion_y > 0.8
  , Center_Distance_y.rank := data.table::frank(
    abs(Center_Distance), 
    ties.method = 'dense'
  )
  , by = .(OBJECTID1, Center_Distance_y.sign)
][
  Center_Distance <= Center_Distance.min.median * 1.5 &
    Center_Distance_Portion_x > 0.8
  , Center_Distance_x.rank := data.table::frank(
    abs(Center_Distance), 
    ties.method = 'dense'
  )
  , by = .(OBJECTID1, Center_Distance_x.sign)
][
  Center_Distance <= Center_Distance.min.median * 1.5
  , Center_Distance.rank := data.table::frank(
    abs(Center_Distance), 
    ties.method = 'dense'
  )
  , by = .(OBJECTID1)
]

# Inspect distribution of Center_Distance_Portion_y
imageDistances.Center_Distance_Portion_y.dist <- imageDistances[
  Center_Distance <= Center_Distance.min.median * 1.5
  , {
    totalImages = .N
    .SD[
      , .(
        pctImages = .N / totalImages
      )
      , keyby = .(
        Center_Distance_Portion_y = floor(Center_Distance_Portion_y * 100)/100
      )
    ]
  }
]

(
  imageDistances.Center_Distance_Portion_y.dist
   %>% 
    ggplot(
      ., 
      aes(
        x = Center_Distance_Portion_y, 
        y = pctImages
      )
    ) + 
    geom_bar(stat = 'identity') + 
    labs(
      x = 'Proportion of pairwise geolocation distance along longitude',
      y = "Percent of geolocation pairs within 150% of each flight's median minimum pairwise distance"
    ) +
    theme_bw()
) %>% 
  ggplotly(.)

# Note: In aggregate, ~86% of 'close geolocation pairs' have the y-proportion
# above 80%. Conversely, ~7% of 'close geolocation pairs' have the x-proportion
# below 95%. I think these represent, e.g., geolocations on islands where it was
# easier for pilots to fly East to West, instead of North to South.
imageDistances.Center_Distance_Portion_y.dist[
  , sum(ifelse(Center_Distance_Portion_y > 0.8, pctImages, 0))
]

imageDistances.Center_Distance_Portion_y.dist[
  , sum(ifelse(Center_Distance_Portion_y < 0.05, pctImages, 0))
]

# Calculate count of adjacent images (within 2x the median minimal pairwise 
# distance for each flight) that are the closest along longitude (+/-)
imageDistances[
  Center_Distance_y.rank == 1 |
    Center_Distance_x.rank == 1
  , Neighbor_Count := .N
  , by = .(OBJECTID1)
][
  Center_Distance_y.rank == 1 &
    Center_Distance > 0
  , Neighbor_Count.y := .N
  , by = .(OBJECTID1)
][
  Center_Distance_x.rank == 1 &
    Center_Distance > 0
  , Neighbor_Count.x := .N
  , by = .(OBJECTID1)
]

# Neighbor Count (in predominantly x & y directions) is mostly 2
imageDistances[
  Center_Distance_y.rank == 1 |
    Center_Distance_x.rank == 1
  , {
    totalImages = .N
    .SD[
      , .(
        N = .N / totalImages
      )
      , keyby = .(Neighbor_Count)
    ]
  }
]

# How many geolocations have uncertain neighbors, i.e., neighbors in both
# x & y directions?
#
# Answer: 3673 geolocations across 24 flights
imageDistances.neighborCounts <- imageDistances[
  , .(
    Neighbor_Count = max(Neighbor_Count, na.rm = TRUE),
    Neighbor_Count.x = max(Neighbor_Count.x, na.rm = TRUE),
    Neighbor_Count.y = max(Neighbor_Count.y, na.rm = TRUE)
  )
  , by = .(FlightID1, OBJECTID1)
][
  is.infinite(Neighbor_Count)
  , Neighbor_Count := NA
][
  is.infinite(Neighbor_Count.x)
  , Neighbor_Count.x := NA
][
  is.infinite(Neighbor_Count.y)
  , Neighbor_Count.y := NA
]

imageDistances.uncertainNeighbors <- imageDistances.neighborCounts[
  (!is.na(Neighbor_Count.x) & Neighbor_Count != Neighbor_Count.x) |
    (!is.na(Neighbor_Count.y) & Neighbor_Count != Neighbor_Count.y)
]  

# What proportion of geolocations in each flight have uncertain neighbors?
#
# At worst, ~45% for flight AXN_1953
imageDistances.uncertainNeighbors[
  , .(
    numUncertainNeighbors = .N
  )
  , by = .(FlightID = FlightID1)
][order(-numUncertainNeighbors)][
  geolocations[, .N, keyby = .(FlightID)]
  , on = .(FlightID)
  , pctUncertainNeighbors := numUncertainNeighbors / i.N
][order(-pctUncertainNeighbors)]

# Append Neighbor_Count to geolocations
geolocations[
  imageDistances[
    , .N
    , keyby = .(OBJECTID1, Center_Distance.min.median)
  ]
  , on = .(OBJECTID = OBJECTID1)
  , Center_Distance.min.median := i.Center_Distance.min.median
][
  imageDistances.neighborCounts
  , on = .(FlightID = FlightID1, OBJECTID = OBJECTID1)
  , `:=` (
    Neighbor_Count = i.Neighbor_Count,
    Neighbor_Count.x = i.Neighbor_Count.x,
    Neighbor_Count.y = i.Neighbor_Count.y
  )
]

# Inspect Neighbor_Count for reasonableness
flightID <- 'BTM_1954'

factpal <- leaflet::colorFactor(
  topo.colors(4), 
  geolocations[FlightID == (flightID), Neighbor_Count]
)

leaflet(options = leafletOptions(preferCanvas = TRUE)) %>%
  addProviderTiles(
    providers$CartoDB.PositronNoLabels,
    group = 'CartoDB.NoLabels',
    options = providerTileOptions(
      updateWhenZooming = FALSE,
      updateWhenIdle = TRUE
    )
  ) %>%
  addCircleMarkers(
    data = geolocations[FlightID == (flightID)],
    lat = ~Latitude,
    lng = ~Longitude,
    radius = rep(
      0.25, 
      nrow(geolocations[FlightID == (flightID)])
    ),
    color = ~factpal(Neighbor_Count),
    label = ~paste0(
      'ID: ', OBJECTID, 
      ', Neighbor_Count: ', Neighbor_Count,
      ', Neighbor_Count.x: ', Neighbor_Count.x,
      ', Neighbor_Count.y: ', Neighbor_Count.y)
  ) %>%
  # addCircles(
  #   data = geolocations[FlightID == (flightID)],
  #   lat = ~Latitude,
  #   lng = ~Longitude,
  #   radius = geolocations[
  #     FlightID == (flightID)
  #   ][
  #     1
  #     , 1.5 * Center_Distance.min.median
  #   ],
  #   color = 'red'
  # ) %>%
  addMeasure(
    position = "bottomleft",
    primaryLengthUnit = "meters",
    primaryAreaUnit = "sqmeters",
    activeColor = "#3D535D",
    completedColor = "#7D4479"
  )
