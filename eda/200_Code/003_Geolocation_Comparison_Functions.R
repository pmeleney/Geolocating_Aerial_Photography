calculateFlightSimilarity <- function(
  overlappingFlightPairs,
  imageGeolocations
) {
  data.table::rbindlist(lapply(
    jaccardSimilarities <- as.list(transpose(overlappingFlightPairs)),
    function(flight_pair) {
      flight1 <- flight_pair[1]
      flight2 <- flight_pair[2]
      
      flightProduct <- imageGeolocations[FlightID == (flight1)][
        imageGeolocations[FlightID == (flight2)]
        , on = .(one)
        , allow.cartesian = TRUE
      ][
        , .(
          FlightID1 = FlightID,
          FlightID2 = i.FlightID,
  
          OBJECTID1 = OBJECTID,
          Year1 = Year,
          Longitude1 = Longitude, 
          Latitude1 = Latitude,
  
          OBJECTID2 = i.OBJECTID,
          Year2 = i.Year,
          Longitude2 = i.Longitude, 
          Latitude2 = i.Latitude,
  
          Center_Distance = gpsDistance(
            Latitude, Longitude, i.Latitude, i.Longitude
          )
        )
      ][
      # Aggregate flights and calculate Jaccard similarity
        , Intersecting_Ind := data.table::fifelse(
          Center_Distance < 1e3,
          1L,
          0L
        )
      ][
        , `:=` (
          FlightID1_Count = data.table::uniqueN(OBJECTID1),
          FlightID2_Count = data.table::uniqueN(OBJECTID2)
        )
        , by = .(FlightID1, FlightID2)
      ][
        , Flight_Pair := paste0(FlightID1, '-', FlightID2)
      ]
      
      data.table::melt(
        flightProduct,
        id.vars = c(
          'Flight_Pair',
          paste0('Year', 1:2), 
          paste0('FlightID', 1:2, '_Count'), 
          'Intersecting_Ind'
        ), 
        measure = list(
          paste0('FlightID', 1:2), paste0('OBJECTID', 1:2)
        ),
        value.name = c('FlightID', 'OBJECTID')
      )[
        , .(
          # Determine if each image in a flight pair shares a 1 km region with
          # any image in the other flight
          Shared_Region_Ind = max(Intersecting_Ind)
        )
        , keyby = .(
          Flight_Pair, Year1, Year2, FlightID1_Count, FlightID2_Count, variable, 
          OBJECTID
        )
      ][
        , .(
          Pct_Flight1_Shared = sum(
            data.table::fifelse(
              variable == 1,
              Shared_Region_Ind, 
              0
            )
          ) / FlightID1_Count,
          Pct_Flight2_Shared = sum(
            data.table::fifelse(
              variable == 2,
              Shared_Region_Ind, 
              0
            )
          ) / FlightID2_Count,
          Jaccard_Similarity = sum(Shared_Region_Ind) / .N
        )
        , keyby = .(Flight_Pair, Year1, Year2, FlightID1_Count, FlightID2_Count)
      ][
        , paste0('FlightID', 1:2) := data.table::transpose(
          stringi::stri_split_fixed(Flight_Pair, '-')
        )
      ][
        , mget(
          c(
            paste0('FlightID', 1:2),
            paste0('Year', 1:2),
            paste0('FlightID', 1:2, '_Count'),
            paste0('Pct_Flight', 1:2, '_Shared'),
            'Jaccard_Similarity'
          )
        )
      ]
    }
  ))[
    order(-Jaccard_Similarity)
  ]
  
  return(jaccardSimilarities)
}

calculateImageDistances <- function(
  flightPairs,
  imageGeolocations
) {
  if(!('cartesianPredicate' %in% names(imageGeolocations))) {
    imageGeolocations[, cartesianPredicate := 1L]
  }
  
  imageDistances <- data.table::rbindlist(lapply(
    as.list(data.table::transpose(flightPairs)),
    function(flight_pair) {
      flight1 <- flight_pair[1]
      flight2 <- flight_pair[2]
      
      # Do cartesian product of geolocations between flight pair
      flightProduct <- imageGeolocations[FlightID == (flight1)][
        imageGeolocations[FlightID == (flight2)]
        , on = .(cartesianPredicate)
        , allow.cartesian = TRUE
      ][
        # When flight1 = flight2, ignore comparing a geolocation with itself.
        OBJECTID != i.OBJECTID
        , .(
          FlightID1 = FlightID,
          FlightID2 = i.FlightID,
  
          OBJECTID1 = OBJECTID,
          Year1 = Year,
          Longitude1 = Longitude, 
          Latitude1 = Latitude,
  
          OBJECTID2 = i.OBJECTID,
          Year2 = i.Year,
          Longitude2 = i.Longitude, 
          Latitude2 = i.Latitude,
  
          Center_Distance = gpsDistance(
            Latitude, Longitude, i.Latitude, i.Longitude
          ),
  
          Center_Heading = gpsHeading(
            Latitude, Longitude, i.Latitude, i.Longitude
          )
        )
      ][
        # Derive additional metrics based on distance and heading of each
        # geolocation pair.
        , `:=` (
          Center_Distance_x = sin(Center_Heading) * Center_Distance,
          Center_Distance_y = cos(Center_Heading) * Center_Distance,
          Center_Distance_Portion_x = sin(Center_Heading)^2,
          Center_Distance_Portion_y = cos(Center_Heading)^2,
          Center_Heading_deg = Center_Heading / degreesToRadians
        )
      ]
      
      return(flightProduct)
    }
  ))
  
  imageGeolocations[, cartesianPredicate := NULL]
  
  return(imageDistances)
}
