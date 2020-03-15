###############################################################################
# Purpose of script:
# Calculate proportion of landcover classifications from the National Landcover
# Database for a grid of locations spanning California.

# Import selected geolocations
geolocations.tilesCA <- data.table::fread(
  path.tilesCA, 
  sep = ',', 
  quote = FALSE, 
  stringsAsFactors = FALSE
)

geolocations.tilesCA[
  , Radius_Pixel := sqrt(1500^2 + 1500^2)/2
][
  # Calculate radius in meters using 1 inch = 600 pixels for 1:18,000 scale 
  # images (for Bing tiles).
  #
  # See this UCSB site for details:
  # https://www.library.ucsb.edu/src/airphotos/aerial-photography-scale
  , Radius := Radius_Pixel / 600 * 0.0254 * 18000
]

# Calculate corners of smallest box that can be placed around an image's 
# geolocation when the image's angle relative to North is unknown. This box
# has side lengths equal to twice the image's radius.
#
# Alternatively, this box can be visualized as follows: Pin the photo on a map
# with its geolocation at the photo's center. Spin the photo in 180 degrees.
# The smallest box that contains all image pixels is defined by the following
# four corners.
geolocations.tilesCA[
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

# Check if the NLCD raster is available. Prompt user if not.
if(!file.exists(path.nlcd)) {
  promptUserForNLCD()
}

# Import NLCD img raster
raster.nlcd <- raster::raster(path.nlcd)

# Get shapefile of US at county level and then subset the California counties
shapefile.us <- raster::getData('GADM', country = 'usa', level = 2)
shapefile.ca <- raster::subset(shapefile.us, NAME_1 == 'California')

# Transform the geolocations into SpatialPoints, get a subset of the california
# shapefile corresponding to the geolocations, and get a subset of the NLCD
# raster that contains the geolocations.
list.raster.geolocations <- getRasterSubset(
  locations = geolocations.tilesCA,
  shapefileData = shapefile.ca,
  rasterData = raster.nlcd
)

###############################################################################
## Restate NLCD and geolocation data for ease in extracting land cover
## classifications.

# Cast the on-disc cropped raster to an in-memory matrix.
#
# Note: This requires a few GBs of RAM! Brute force approach...
matrix.nlcd.geolocations <- raster::as.matrix(
  list.raster.geolocations[['raster_subset']]
)

gc()

geolocations.transformed <- convertExtentToIndices(
  listRaster = list.raster.geolocations
)

# Append radius for each image.
#
# Note: Although a direct join isn't easy to setup, the image order should
# equal to that in geolocations. So appending the column as-is should be ok.
geolocations.transformed[
  , Radius := geolocations.tilesCA[['Radius']]
]

###############################################################################
## Calculate proportion of NLCD integer classification in a radius around each
## geolocation consistent with its image dimensions.

# Create row id on which to do row-level calculations
geolocations.transformed[
  , rowID := 1:.N
]

# Calculate land cover classification proportions for each selected geolocation
#
# Note: The following function (and most of this script) is an ad-hoc way of
# approximating:
#
# 
geolocations.transformed[
  , (indices.nlcd) := extractLandCoverFreq(
    lat.index = Latitude.index, 
    lon.index = Longitude.index, 
    sideLength = Radius,
    matNLCD = matrix.nlcd.geolocations
  )
  , by = .(rowID)
]

# Restate the factor levels to formal NLCD classification names
data.table::setnames(
  geolocations.transformed,
  indices.nlcd,
  levels.nlcd
)

# Replace NA's with 0's
geolocations.transformed[
  , (levels.nlcd) := lapply(
    (levels.nlcd), function(landcover)
    ifelse(is.na(get(landcover)), 0, get(landcover))
  )
]

###############################################################################
## Append land cover proportions to selected geolocations

# Create row id to use as join predicate, since the row order did not change
geolocations.tilesCA[
  , rowID := 1:.N
]

geolocations.tilesCA[
  geolocations.transformed
  , on = .(rowID)
  , (levels.nlcd) := mget(levels.nlcd)
]

###############################################################################
## Export results

data.table::fwrite(
  geolocations.tilesCA, 
  file = path.classesTilesCA,
  row.names = FALSE, 
  quote = FALSE
)
