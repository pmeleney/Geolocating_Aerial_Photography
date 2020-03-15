gpsDistance <- function(lat1, lon1, lat2, lon2) {
  # Approximate GPS distance using modified Euclidean distance
  # E.g., see: https://jonisalonen.com/2014/computing-distance-between-coordinates-can-be-simple-and-fast/
  output <- sqrt(
	 (cos(lat2 * degreesToRadians) * (lon2 - lon1))^2 +
	   (lat2 - lat1)^2
	) * 1852 * 60
  
  return(output)
}

gpsHeading <- function(lat1, lon1, lat2, lon2) {
  # Convert decimal degrees to radians
  lat1 <- lat1 * degreesToRadians
  lon1 <- lon1 * degreesToRadians
  lat2 <- lat2 * degreesToRadians
  lon2 <- lon2 * degreesToRadians
  
  deltaLon <- lon2 - lon1
  x <- cos(lat2) * sin(deltaLon)
  y <- cos(lat1) * sin(lat2) - (
    sin(lat1) * 
      cos(lat2) * 
      cos(deltaLon)
  )
  
  heading <- atan2(x, y)
  
  return(heading)
}

translateLocation <- function(lat, lon, dist_lat, dist_lon) {
  # Modified from:
  #    https://stackoverflow.com/a/7478827
  
  rEarth <- 6371000
  lat_new <- lat + (dist_lat / rEarth) / degreesToRadians
  lon_new <- lon + (dist_lon / rEarth) / (
    cos(lat * degreesToRadians) * degreesToRadians
  )
  
  return(list(lat_new, lon_new))
}
