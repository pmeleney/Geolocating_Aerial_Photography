plotFlight <- function(
  flightID,
  imageGeolocations
) {
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
      data = imageGeolocations[FlightID == (flightID)],
      lat = ~Latitude,
      lng = ~Longitude,
      radius = rep(
        0.25, 
        nrow(imageGeolocations[FlightID == (flightID)])
      ),
      color = 'red',
      label = ~OBJECTID
    )
}

plotFlightPair <- function(
  flightID1,
  flightID2,
  imageGeolocations
) {
  leaflet::leaflet(options = leafletOptions(preferCanvas = TRUE)) %>%
    leaflet::addProviderTiles(
      leaflet::providers$CartoDB.PositronNoLabels,
      group = 'CartoDB.NoLabels',
      options = leaflet::providerTileOptions(
        updateWhenZooming = FALSE,
        updateWhenIdle = TRUE
      )
    ) %>%
    leaflet::addCircleMarkers(
      data = imageGeolocations[FlightID == (flightID1)],
      lat = ~Latitude,
      lng = ~Longitude,
      radius = rep(
        0.25, 
        nrow(imageGeolocations[FlightID == (flightID1)])
      ),
      color = 'red',
      label = ~OBJECTID
    ) %>%
    addCircleMarkers(
      data = imageGeolocations[FlightID == (flightID2)],
      lat = ~Latitude,
      lng = ~Longitude,
      radius = rep(
        0.25, 
        nrow(imageGeolocations[FlightID == (flightID2)])
      ),
      color = 'blue',
      label = ~OBJECTID
    )
}

createFlightSpatialPolygonDataFrame <- function(imageGeolocations) {
  # Create arbitrary image number
  imageGeolocations[
    , ImageNumber := 1:.N
    , by = .(FlightID)
  ]
  
  # Compute convex hull for each selected flight
  convexHullIds <- imageGeolocations[
    , .(
      hullImageNumber = chull(Longitude, Latitude)
    )
    , by = .(FlightID)
  ][
    , hullImageOrder := 1:.N
    , by = .(FlightID)
  ]
  
  # Append convex hull indicator for each flight
  imageGeolocations[
      convexHullIds
      , on = .(FlightID, ImageNumber = hullImageNumber)
      , `:=` (
        Hull_Ind = TRUE,
        Hull_Order = i.hullImageOrder
      )
  ]
  
  # Create flight path hull polygons
  flightPathHulls <- imageGeolocations[
    (Hull_Ind)
  ][order(FlightID, Hull_Order)][
    , .(
      Flight_Path_Hull = list(sp::Polygon(cbind(Longitude, Latitude)))
    )
    , by = .(FlightID)
  ]
  
  flightPolygons <- lapply(
    seq(nrow(flightPathHulls)),
    function(index) {
      flightPathHull <- flightPathHulls[['Flight_Path_Hull']][[index]]
      flightID <- flightPathHulls[['FlightID']][[index]]
      
      sp::Polygons(list(flightPathHull), ID = flightID)
    }
  )
  
  flightSpatialPolygons <- sp::SpatialPolygons(flightPolygons)
  
  flightNames <- imageGeolocations[, .N, keyby = .(FlightID)][, FlightID]
  
  flightYearNames <- imageGeolocations[
    , .N
    , keyby = .(FlightID, Year)
  ][, paste0(FlightID, '-', Year)]
  
  flightSpatialPolygonDataFrame <- sp::SpatialPolygonsDataFrame(
    flightSpatialPolygons,
    data.frame(
      flight = factor(flightNames),
      flightYear = factor(flightYearNames)
    ), 
    match.ID = FALSE
  )
  
  # Remove ImageNumber column
  imageGeolocations[
    , ImageNumber := NULL
  ]
  
  return(flightSpatialPolygonDataFrame)
}

plotFlightLandCoverProportions <- function(
  flightID,
  imageGeolocations,
  shapefileData,
  rasterData,
  maxMegabyte = 10
) {
  processedData <- getRasterSubset(
    locations = imageGeolocations[FlightID == (flightID)], 
    shapefileData = shapefileData, 
    rasterData = rasterData
  )
  
  landCoverPalette <- leaflet::colorFactor(
    FedData::pal_nlcd()[['color']], 
    factor(
      raster::values(processedData[['raster_subset']]), 
      levels = indices.nlcd[-1]
    ), 
    na.color = "transparent"
  )
  
  leaflet(options = leaflet::leafletOptions(preferCanvas = TRUE)) %>%
    leaflet::addProviderTiles(
      leaflet::providers$CartoDB.PositronNoLabels,
      group = 'CartoDB.NoLabels',
      options = leaflet::providerTileOptions(
        updateWhenZooming = FALSE,
        updateWhenIdle = TRUE
      )
    ) %>%
    leaflet::addRasterImage(
      processedData[['raster_subset']], 
      colors = landCoverPalette, 
      maxBytes = maxMegabyte * 1024 * 1024
    ) %>%
    leaflet::addCircleMarkers(
      data = imageGeolocations[FlightID == (flightID)],
      lat = ~Latitude,
      lng = ~Longitude,
      radius = rep(
        0.25, 
        nrow(imageGeolocations[FlightID == (flightID)])
      ),
      color = 'black',
      label = ~OBJECTID
    ) %>%
    leaflet::addRectangles(
      data = imageGeolocations[
        FlightID == (flightID)
        , .(
          popupLabel = paste0(
            (levels.nlcd), ': ', floor(.SD * 1e3)/10, 
            collapse = '<br/>'
          ),
          Latitude_topLeft,
          Longitude_topLeft,
          Latitude_bottomRight,
          Longitude_bottomRight,
          OBJECTID
        )
        , .SDcols = (levels.nlcd)
        , by = .(rowID)
      ][
        , .(
          popupLabel = paste0(
            paste0('OBJECTID: ', OBJECTID, '<br/><br/>'),
            popupLabel
          ),
          Latitude_topLeft,
          Longitude_topLeft,
          Latitude_bottomRight,
          Longitude_bottomRight
        )
      ],
      lat1 = ~Latitude_topLeft,
      lng1 = ~Longitude_topLeft,
      lat2 = ~Latitude_bottomRight,
      lng2 = ~Longitude_bottomRight,
      fillColor = "transparent",
      popup = ~popupLabel
    ) %>%
    leaflet::addMeasure(
      position = "bottomleft",
      primaryLengthUnit = "meters",
      primaryAreaUnit = "sqmeters",
      activeColor = "#3D535D",
      completedColor = "#7D4479"
    )
}

plotClassifiedPartitions <- function(
  flightID, 
  imagePartitionClassifications,
  showGeolocations = FALSE
) {
  meanClassProbs <- imagePartitionClassifications[
    FlightID == (flightID)
    , lapply(.SD, mean)
    , by = .(FlightID)
    , .SDcols = (namesClassProbs)
  ] %>%
    data.table::melt(
      .,
      id.vars = 'FlightID', 
      variable.name = 'groupID',
      variable.factor = FALSE,
      value.name = 'classProb'
    )
  
  meanClassProbs[
    , groupID := stringi::stri_replace_all_fixed(groupID, 'prob_', '') %>% 
      as.integer
  ]
  
  meanClassProbs[
    partitionIDs
    , on = .(groupID)
    , `:=` (
      Latitude_groupIDCenter = i.Latitude_groupID + 0.25, 
      Longitude_groupIDCenter = i.Longitude_groupID + 1/3
    )
  ][
    , `:=` (
      Latitude_groupID_topLeft = Latitude_groupIDCenter - 0.25,
      Longitude_groupID_topLeft = Longitude_groupIDCenter + 1/3,
      Latitude_groupID_bottomRight = Latitude_groupIDCenter + 0.25,
      Longitude_groupID_bottomRight = Longitude_groupIDCenter - 1/3
    )
  ]
  
  classProbPal <- leaflet::colorNumeric(
    palette = 'Spectral',
    # Using a fixed scale with max mean probability of 28% because the largest
    # mean probability across all selected flights is ~27%.
    domain = c(0, 0.28),
    # domain = meanClassProbs[, classProb],
    reverse = TRUE
  )
  
  maxClassProb <- meanClassProbs[, max(classProb)]
  
  if(showGeolocations) {
    leaflet::leaflet(options = leaflet::leafletOptions(preferCanvas = TRUE)) %>%
      leaflet::addProviderTiles(
        leaflet::providers$CartoDB.PositronNoLabels,
        group = 'CartoDB.NoLabels',
        options = leaflet::providerTileOptions(
          updateWhenZooming = FALSE,
          updateWhenIdle = TRUE
        )
      ) %>%
      leaflet::addRectangles(
        data = meanClassProbs,
        lat1 = ~Latitude_groupID_topLeft, 
        lng1 = ~Longitude_groupID_topLeft,
        lat2 = ~Latitude_groupID_bottomRight,
        lng2 = ~Longitude_groupID_bottomRight,
        fillOpacity  = ~classProb / maxClassProb,
        fillColor = ~classProbPal(classProb),
        opacity  = ~classProb / maxClassProb,
        color = ~classProbPal(classProb),
        popup = ~paste0(
          'Partition ', groupID, ': ', 
          'Classifier Probability: ', floor(classProb * 1e3) / 10, '%'
        )
      ) %>%
      leaflet::addCircleMarkers(
        data = imagePartitionClassifications[FlightID == (flightID)],
        lat = ~Latitude,
        lng = ~Longitude,
        radius = 0.25,
        color = 'blue',
        label = ~Frame
      ) %>%
      leaflet::addMeasure(
        position = "bottomleft",
        primaryLengthUnit = "meters",
        primaryAreaUnit = "sqmeters",
        activeColor = "#3D535D",
        completedColor = "#7D4479"
      )
  } else {
    leaflet::leaflet(options = leaflet::leafletOptions(preferCanvas = TRUE)) %>%
      leaflet::addProviderTiles(
        leaflet::providers$CartoDB.PositronNoLabels,
        group = 'CartoDB.NoLabels',
        options = leaflet::providerTileOptions(
          updateWhenZooming = FALSE,
          updateWhenIdle = TRUE
        )
      ) %>%
      leaflet::addRectangles(
        data = meanClassProbs,
        lat1 = ~Latitude_groupID_topLeft, 
        lng1 = ~Longitude_groupID_topLeft,
        lat2 = ~Latitude_groupID_bottomRight,
        lng2 = ~Longitude_groupID_bottomRight,
        fillOpacity  = ~classProb / maxClassProb,
        fillColor = ~classProbPal(classProb),
        opacity  = ~classProb / maxClassProb,
        color = ~classProbPal(classProb),
        popup = ~paste0(
          'Partition ', groupID, ': ', 
          'Classifier Probability: ', floor(classProb * 1e3) / 10, '%'
        )
      ) %>%
      leaflet::addMeasure(
        position = "bottomleft",
        primaryLengthUnit = "meters",
        primaryAreaUnit = "sqmeters",
        activeColor = "#3D535D",
        completedColor = "#7D4479"
      )
  }
}
