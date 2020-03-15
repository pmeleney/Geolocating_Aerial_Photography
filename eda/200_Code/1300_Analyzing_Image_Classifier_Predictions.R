################################################################################
# Purpose of script:
# This script analyzes the CNN classifications of aerial photos from selected
# flights. These classifications are an experiment to geolocate the aerial
# photos into 1 of 160 partitions of California.

if(!file.exists(path.cnn_results)) {
  unzip(
    paste0(tools::file_path_sans_ext(path.cnn_results), '.zip'), 
    exdir = folder.data
  )
}

classified_photos <- data.table::fread(
  path.cnn_results, 
  sep = ',', 
  header = TRUE
)

classified_photos[
  , `:=` (
    flight_name = toupper(flight_name) %>% 
      stringi::stri_replace_all_fixed(., '-', '_'),
    image_frame = toupper(image_frame)
  )
]

data.table::setnames(
  classified_photos,
  c('flight_name', 'image_frame'),
  c('FlightID', 'Frame')
)

# Import geolocations and append locations.
geolocations <- data.table::fread(
  path.selected_geolocations, 
  sep = ',', 
  quote = FALSE, 
  stringsAsFactors = FALSE
)

classified_photos[
  geolocations
  , on = .(FlightID, Frame)
  , `:=` (
    Latitude = i.Latitude,
    Longitude = i.Longitude
  )
]

data.table::setcolorder(
  classified_photos,
  c(
    "FlightID", "Frame", "likely_class", "likely_class_prob", 'Latitude', 
    'Longitude', paste0('prob_', c(1:30, 32:97, 99:159))
  )
)

# Import California partitions
gridCA <- data.table::fread(
  path.labelsCA,
  sep = ',', 
  quote = FALSE, 
  stringsAsFactors = FALSE
)

partitionIDs <- gridCA[
  , .N
  , keyby = .(
    groupID,
    Latitude_groupID = floor(Latitude_groupID * 1e3)/1e3,
    Longitude_groupID = floor(Longitude_groupID * 1e3)/1e3
  )
]

# Calculate actual CA partition
classified_photos[
  , `:=` (
    Latitude_groupID = floor(floor(Latitude * 2) / 2 * 1e3) / 1e3, 
    Longitude_groupID = floor(floor(Longitude * 1.5) / 1.5 * 1e3) / 1e3
  )
]

classified_photos[
  partitionIDs
  , on = .(Latitude_groupID, Longitude_groupID)
  , groupID := i.groupID,
]

classified_photos[
  partitionIDs
  , on = .(likely_class = groupID)
  , `:=` (
    Latitude_likelyGroupIDCenter = i.Latitude_groupID + 0.25, 
    Longitude_likelyGroupIDCenter = i.Longitude_groupID + 1/3
  )
]

namesClassProbs <- paste0('prob_', c(1:30, 32:97, 99:159))

data.table::setcolorder(
  classified_photos,
  c(
    "FlightID", "Frame", "likely_class", "likely_class_prob", 
    'Latitude_likelyGroupIDCenter', 'Longitude_likelyGroupIDCenter', 'Latitude', 
    'Longitude', 'groupID', 'Latitude_groupID', 'Longitude_groupID', 
    namesClassProbs
  )
)

# 25 photos could not be joined by (Latitude_groupID, Longitude_groupID) due
# to 3 NA values (from photos that apparently lack geolocations) & the rest
# have (Latitude_groupID, Longitude_groupID) values omitted in the CA partitions

# Calculate accuracy between likely_class (CNN prediction) & groupID (true 
# value) for each flight.

classified_photos[
  , distance_km_a2e := gpsDistance(
    Latitude, Longitude, 
    Latitude_likelyGroupIDCenter, Longitude_likelyGroupIDCenter
  ) / 1000
]

classified_photos[
  likely_class != groupID
  , mean_distance_km_unequal := mean(
      distance_km_a2e,
      na.rm = TRUE
    )
  , by = .(FlightID)
]

classified_photos_accuracy <- classified_photos[
  !is.na(groupID)
  , .(
    correctCount = sum(ifelse(
      likely_class == groupID,
      1L,
      0L
    ), na.rm = TRUE),
    accuracy = sum(ifelse(
      likely_class == groupID,
      1L,
      0L
    ), na.rm = TRUE) / .N,
    mean_distance_km_unequal = max(mean_distance_km_unequal, na.rm = TRUE)
  )
  , keyby = .(FlightID)
][
  order(-accuracy)
]

# Plot actual vs expected
# Add grid box
classified_photos[
  , `:=` (
    Latitude_likelyGroupID_topLeft = Latitude_likelyGroupIDCenter - 0.25,
    Longitude_likelyGroupID_topLeft = Longitude_likelyGroupIDCenter + 1/3,
    Latitude_likelyGroupID_bottomRight = Latitude_likelyGroupIDCenter + 0.25,
    Longitude_likelyGroupID_bottomRight = Longitude_likelyGroupIDCenter - 1/3
  )
]

classified_photos_likelyPct <- classified_photos[
  , {
    totalImageCount = .N
    .SD[
      , .(
        imageCount = .N,
        imagePct = .N / totalImageCount
      )
      , keyby = .(likely_class)
    ]
  }
  , keyby = .(FlightID)
]

classified_photos_groupIDPct <- classified_photos[
  , {
    totalImageCount = .N
    .SD[
      , .(
        imageCount = .N,
        imagePct = .N / totalImageCount
      )
      , keyby = .(groupID)
    ]
  }
  , keyby = .(FlightID)
]

plotClassifiedPartitions(
  flightID = 'ABB_1957', 
  imagePartitionClassifications = classified_photos,
  showGeolocations = TRUE
)

plotClassifiedPartitions(
  flightID = 'AXI_1959', 
  imagePartitionClassifications = classified_photos,
  showGeolocations = TRUE
)

plotClassifiedPartitions(
  flightID = 'ABL_1952', 
  imagePartitionClassifications = classified_photos,
  showGeolocations = TRUE
)
