# Investigating the partitioning of CA for direct geolocation

# Define partitions based on location
gridCA <- data.table::fread(
  path.tilesCA,
  sep = ',', 
  quote = FALSE, 
  stringsAsFactors = FALSE
)

gridCA[
  , `:=` (
    groupID = .GRP,
    Latitude_groupID = floor(Latitude * 2) / 2, 
    Longitude_groupID = floor(Longitude * 1.5) / 1.5
  )
  # This partitioning yields cells on the order of 54 km x 52 km
  , by = .(
    Latitude = floor(Latitude * 2) / 2, 
    Longitude = floor(Longitude * 1.5) / 1.5
  )
]

numGroupsCA <- gridCA[, length(unique(groupID))]

factpal <- leaflet::colorFactor(
  RColorBrewer::brewer.pal(8, 'Paired') %>% 
    sample(., numGroupsCA, replace = TRUE),
  gridCA[, groupID]
)

leaflet::leaflet(options = leaflet::leafletOptions(preferCanvas = TRUE)) %>%
  leaflet::addProviderTiles(
    leaflet::providers$CartoDB.PositronNoLabels,
    group = 'CartoDB.NoLabels',
    options = leaflet::providerTileOptions(
      updateWhenZooming = FALSE,
      updateWhenIdle = TRUE
    )
  ) %>%
  leaflet::addCircleMarkers(
    data = gridCA,
    lat = ~Latitude,
    lng = ~Longitude,
    radius = 0.25,
    color = ~factpal(groupID),
    label = ~groupID
  ) %>%
  leaflet::addMeasure(
    position = "bottomleft",
    primaryLengthUnit = "meters",
    primaryAreaUnit = "sqmeters",
    activeColor = "#3D535D",
    completedColor = "#7D4479"
  )
