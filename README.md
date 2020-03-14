# Geolocating Aerial Photography

## Find North

The purpose of this Jupyter Notebook is to determine the orientation of two geo-located aerial photographs.  The main function is FindNorth.find_north().  It takes the location of two .tif image files, two tuples describing the lat and long of the centerpoints of those images, and a string ("SIFT". "ORB", or "BRISK") which determines which feature descriptor is used to determine the location of keypoints in the input images.  Opencv-python 3.4.2.17 and opencv-contrib-python 3.4.2.17 or earlier are required to run the "SIFT" algorithm.

To run the demo script call the function with any two consecutive images found in demo/find_north/images/c-300/.  For images c-300_a-1.tif and c-300_a-2.tif the returned rotations to true north should be 11.33 degrees and 9.78 degrees respectively.


## Topo Compare

