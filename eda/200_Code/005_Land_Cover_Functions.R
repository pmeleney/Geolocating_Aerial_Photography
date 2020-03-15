#' Prompt User To Obtain NLCD
#' 
#' Ask user to download and then unzip the very large NLCD zip, i.e., 1.4 GBs compressed and 20 GBs uncompressed.
#'
#' @export
#'
promptUserForNLCD <- function() {
  promptResponses <- c('Yes', 'No')
  
  promptForDownload <- menu(
    promptResponses,
    title = 'Do you want to download the NLCD 2016 Land Cover zip? (1.4 GBs)'
  )
  
  if(promptForDownload == 1) {
    download.file(
      url = file.path(
        'https://s3-us-west-2.amazonaws.com', 
        'mrlc', 
        paste0(name.nlcd, '.zip')
      ), 
      destfile = path.nlcd
    )
  }
  
  promptForUnzipping <- menu(
    promptResponses,
    title = 'Do you want to unzip the NLCD 2016 Land Cover file? (20 GBs)'
  )
  
  if(promptForUnzipping == 1) {
    unzip()
  } else{
    stop('The proceeding code requires the NLCD 2016 Land Cover file to be unzipped.')
  }
}

#' Get Shapefile Subset Containing Locations
#'
#' @param locations 
#' @param shapefileData 
#' @param crs 
#'
#' @return \code{list}
#' @export
#'
getShapefileSubset <- function(locations, shapefileData, crs) {
  # Modified from:
  #    https://stackoverflow.com/a/15892557
  locations <- data.table::copy(locations)
  
  coordinates(locations) <- c("Longitude",  "Latitude")
  sp::proj4string(locations) <- 
    sp::CRS("+proj=longlat +ellps=WGS84 +datum=WGS84")
  
  locations.transformed <- sp::spTransform(
    locations, 
    crs
  )
  
  shapefile.transformed <- sp::spTransform(
    shapefileData,
    crs
  )
  
  shapefile.intersection <- sp::over(
    locations.transformed, 
    shapefile.transformed
  )
  
  output <- list(
    'locations_transformed' = locations.transformed,
    'shapefile_transformed' = shapefile.transformed,
    'shapefile_intersection' = shapefile.intersection
  )
  
  return(output)
}

#' Get Subset of Raster Image
#' 
#' Find subset of raster image \code{rasterData} that contains all locations in \code{locations} using a union of shapes from \code{shapefileData}.
#'
#' @param locations \code{data.table} of locations with columns 'Latitude' and 'Longitude'
#' @param shapefileData shapefile
#' @param rasterData \code{raster} image
#'
#' @return list of raster subset, unioned shapes, and projected locations consistent with the raster
#' @export
#'
getRasterSubset <- function(locations, shapefileData, rasterData) {
  # Modified from:
  #    https://stackoverflow.com/a/15892557
  
  list.shapefileSubset <- getShapefileSubset(
   locations = locations, 
   shapefileData = shapefileData, 
   crs = sp::CRS(rasterData@crs@projargs)
  )
  
  locations.transformed <- list.shapefileSubset[['locations_transformed']]
  shapefile.transformed <- list.shapefileSubset[['shapefile_transformed']]
  shapefile.intersection <- list.shapefileSubset[['shapefile_intersection']]
  
  shapefile.locations <- subset(
    shapefile.transformed, 
    GID_2 %in% data.table::as.data.table(
      shapefile.intersection
    )[, unique(GID_2)]
  )
  
  raster.locations <- raster::crop(
    rasterData, 
    raster::extent(shapefile.locations)
  )
  
  output <- list(
    'locations_transformed' = locations.transformed,
    'shapefile_transformed' = shapefile.locations,
    'raster_subset' = raster.locations
  )
  
  return(output)
}

#' Convert Extent Coordinates to Raster Indices
#' 
#' Create a lookup \code{data.table} for the transformed locations in \code{listRaster} that maps between extent coordinates and raster indices consistent with the raster in \code{listRaster}.
#'
#' @param listRaster output from \code{getRasterSubset}
#'
#' @return \code{data.table} representing locations in both extent coordinates and raster indices
#' @export
#'
convertExtentToIndices <- function(listRaster) {
  # Cast the SpatialPoints object to a data.table for ease in manipulation
  locations.transformed <- data.table::as.data.table(
    listRaster[['locations_transformed']]
  )
  
  res <- raster::res(listRaster[['raster_subset']])
  xmin <- listRaster[['raster_subset']]@extent@xmin
  ymin <- listRaster[['raster_subset']]@extent@ymin
  maxLatitudeIndex <- dim(listRaster[['raster_subset']])[1]
  
  locations.transformed[
    , `:=` (
      Longitude.index = floor((Longitude - xmin)/res[1]),
      Latitude.index = maxLatitudeIndex - floor((Latitude - ymin)/res[2])
    )
  ]
  
  return(locations.transformed)
}

#' Create Sequence of Centered Indices
#' 
#' Create a sequence of integers centered on \code{center} with \code{radius}-many sequential integers below and above \code{center}. Only positive indices are returned and capped at \code{maxValue}.
#'
#' @details E.g., \code{seq_centered(5, 10, 13) = 1:13}
#'
#' @param center \code{integer}
#' @param radius \code{integer}
#' @param maxValue \code{integer}
#'
#' @return
#' @export
#'
seq_centered <- function(center, radius, maxValue) {
  output <- c(
    seq(from = center - radius, to = center - 1),
    center,
    seq(from = center + 1, to = center + radius)
  )
  
  return(output[output > 0 & output <= maxValue])
}

#' Extract Matrix Values with Square Grid of Indices
#' 
#' Extract values from matrix \code{mat} using a square grid of indices with side length equal to \code{sideLength} and centered at row \code{rowNum} & column \code{colNum}.
#'
#' @param rowNum row number of \code{mat} representing center of square grid of indices
#' @param colNum column number of \code{mat} representing center of square grid of indices
#' @param sideLength side length of square grid of indices
#' @param mat matrix with values to be extracted
#'
#' @return \code{matrix}, subset of \code{mat}
#' @export
#'
extractMatrixIndices <- function(
  rowNum, 
  colNum, 
  sideLength, 
  mat
) {
  matDims <- dim(mat)
  
  output <- mat[
    seq_centered(center = rowNum, radius = sideLength, maxValue = matDims[1]),
    seq_centered(center = colNum, radius = sideLength, maxValue = matDims[2])
  ]
  
  return(output)
}

#' Summarize Matrix
#' 
#' Calculate the proportion of observed values from matrix \code{mat} as a list with names assigned by \code{indices}.
#'
#' @param mat matrix used to calculate proportions
#' @param levelNames 
#'
#' @return named \code{list} of proportions
#' @export
#'
summarizeMatrix <- function(mat, levelNames) {
  matSummary <- table(mat)
  numValues <- sum(matSummary)
  matSummary <- as.list(matSummary / numValues)
  
  output <- vector(mode = "list", length = length(levelNames))
  names(output) <- levelNames
  output[names(output)] <- rep(NA_real_, length(levelNames))
  
  output[names(matSummary)] <- unname(matSummary)
  
  return(output)
}

#' Extract Land Cover Frequencies
#' 
#' Obtain list of land cover frequencies from \code{summarizeMatrix} using a square grid of NLCD raster indices from \code{matNLCD} that is centered at raster row \code{lat.index} and raster column \ode{lon.index}.
#' 
#' @details Note: This function approximates the raster::extract function which appears very slow when applied to thousands of regions.
#'
#' @param lat.index latitude of index grid center transformed to raster index
#' @param lon.index longitude of index grid center transformed to raster index
#' @param sideLength length in meters around of square region side length with center at (latitude, longitude)
#' @param matNLCD \code{matrix} of land cover classifications
#' @param res resolution in meters of \code{matNLCD}
#'
#' @return named \code{list} of land cover proportions
#' @export
#'
extractLandCoverFreq <- function(
  lat.index, 
  lon.index, 
  sideLength, 
  matNLCD, 
  res = 30
) {
  # Convert sideLength in meters to sideLength in pixels according to NLCD 
  # resolution.
  #
  # Note: Using ceiling to ensure the full radius in meters is included in the
  # land cover proportion table.
  sideLength <- ceiling(sideLength / res)
  
  landCoverMatrix <- extractMatrixIndices(
    rowNum = lat.index,
    colNum = lon.index,
    sideLength = sideLength,
    mat = matNLCD
  )
  
  output <- summarizeMatrix(
    mat = landCoverMatrix, 
    levelNames = indices.nlcd
  )
  
  return(output)
}
