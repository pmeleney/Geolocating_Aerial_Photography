###############################################################################
# Purpose of script:
# 1) Filter flights having the following properties:
#   * Every image has the same date for that flight
#   * The flight date occurs between 1952 & 1965
#   * The flights has at least 500 images
#   * The image scale is always 1:20,000
#
# 2) Append image dimensions for each geolocation
#
# 3) Derive additional metrics based on image dimensions
#
# 4) Export resulting table

###############################################################################
## 1) Filter selected flights

# Import raw geolocations
geolocations <- data.table::fread(
  path.geolocations, sep = '|', quote = FALSE, stringsAsFactors = FALSE
)

# Flag rows that require requesting the scanned photo (i.e., the blank ones
# for the Scan column)
geolocations[
  , ScanAvailable := ifelse(
    Scan == '',
    FALSE,
    TRUE
  )
]

geolocations[
  # Cast BeginDate as Date type
  , Date := data.table::as.IDate(BeginDate)
][
  , `:=` (
    Year = year(Date),
    US_Ind = ifelse(
      y %between% boundingLat.US & x %between% boundingLon.US,
      1, 0
    ),
    CA_Ind = ifelse(
      y %between% boundingLat.CA & x %between% boundingLon.CA,
      1, 0
    )
  )
]

# Make explicit which fields are lat/lon
data.table::setnames(
  geolocations,
  c('x', 'y'),
  c('Longitude', 'Latitude')
)

# Only keep available images
geolocations <- geolocations[(ScanAvailable)]

# Find flights with multiple dates
flights.multidate <- geolocations[
  , .(
    dateCount = data.table::uniqueN(Date)
  )
  , keyby = .(FlightID)
][
  dateCount > 1
]

# Find subset of geolocations that come from single-date flights
geolocations.singledate_flights <- geolocations[
  !flights.multidate
  , on = .(FlightID)
]

# Find subset of flights between 1952-1965, with at least 500 images, 
# and 1:20,000 in scale
flights.selected <- geolocations.singledate_flights[
    Year %in% 1952:1965
    , .(
      Image_Count = .N
    )
    , keyby = .(FlightID, Year, Scale)
][
    Image_Count > 500 & Scale == 20000
    , .(
      FlightID,
      Year,
      Scale,
      Image_Count,
      # At present time, we plan on sampling at least 500 or at most 1500 images
      # from these selected flights. The capped image count column shows how
      # many images would be sampled for each flight.
      Capped_Image_Count = ifelse(
          Image_Count > 1500,
          1500,
          500
      )
    )
]

# Find subset of geolocations between 1952-1965, with at least 500 images, 
# and 1:20,000 in scale
geolocations.selected <- geolocations.singledate_flights[
  flights.selected
  , on = .(FlightID)
  , nomatch = FALSE
]

# Remove duplicate columns
geolocations.selected[
  , `:=` (
    i.Year = NULL,
    i.Scale = NULL
  )
]

###############################################################################
## 2) Append image dimensions for each geolocation

# Extract image filename to use as join predicate with imageDimensions
geolocations.selected[
  , filename := basename(Scan)
]

# Import image dimensions to later join with selected geolocations
imageDimensions <- data.table::fread(
  path.dimensions, 
  sep = ',', 
  quote = FALSE, 
  stringsAsFactors = FALSE
)

# Keep only filename, remove the file path
imageDimensions[
  , filename := basename(filename)
]

# Append image dimensions to selected geolocations
geolocations.selected[
  imageDimensions
  , on = .(filename)
  , `:=` (
    Image_Height = i.height,
    Image_Width = i.width
  )
]

###############################################################################
## 3) Derive additional metrics based on image dimensions

# Calculate the radius in pixels from the center of each image
#
# Note: This assumes that each geolocation is at the center of each image
geolocations.selected[
  , Radius_Pixel := sqrt(Image_Height^2 + Image_Width^2)/2
][
  # Calculate radius in meters using 1 inch = 600 pixels for 1:20,000 scale 
  # images.
  #
  # See this UCSB site for details:
  # https://www.library.ucsb.edu/src/airphotos/aerial-photography-scale
  , Radius := Radius_Pixel / 600 * 0.0254 * 20000
]

# Calculate corners of smallest box that can be placed around an image's 
# geolocation when the image's angle relative to North is unknown. This box
# has side lengths equal to twice the image's radius.
#
# Alternatively, this box can be visualized as follows: Pin the photo on a map
# with its geolocation at the photo's center. Spin the photo in 180 degrees.
# The smallest box that contains all image pixels is defined by the following
# four corners.
geolocations.selected[
  , c(
    'Latitude_topLeft',
    'Longitude_topLeft',
    'Latitude_bottomRight',
    'Longitude_bottomRight'
  ) := t(
    c(
      translateLocation(Latitude, Longitude, Radius, -Radius), 
      translateLocation(Latitude, Longitude, -Radius, Radius)
    )
  )
]

###############################################################################
## 4) Export combined table

# Export selected geolocations
data.table::fwrite(
  geolocations.selected, 
  file = path.selected_geolocations,
  row.names = FALSE, 
  quote = FALSE
)
