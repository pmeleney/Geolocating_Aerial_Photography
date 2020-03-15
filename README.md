# Geolocating Aerial Photography

## Find North

The purpose of this Jupyter Notebook is to determine the orientation of two geo-located aerial photographs.  The main function is FindNorth.find_north().  It takes the location of two .tif image files, two tuples describing the lat and long of the centerpoints of those images, and a string ("SIFT". "ORB", or "BRISK") which determines which feature descriptor is used to determine the location of keypoints in the input images.  Opencv-python 3.4.2.17 and opencv-contrib-python 3.4.2.17 or earlier are required to run the "SIFT" algorithm.

To run the demo script call the function with any two consecutive images found in demo/find_north/images/c-300/.  For images c-300_a-1.tif and c-300_a-2.tif the returned rotations to true north should be 11.33 degrees and 9.78 degrees respectively.


## Topo Compare

The purpose of this Jupyter Notebook is to geolocate images of unknown location using Topography Reconstruction.  This process involves using the COLMAP tool, which is available here: https://colmap.github.io/.

Running the Demo:
Demonstration data is available under colmap_reconstructions/btm-1954.  The files in this repository can be entered into the TopoCompare.topo_compare() function as shown in the Demo section of the notebook.  Running this demonstration should only take a few minutes as it only searches a small portion of California.  Results (df_min) should be as follows:

       | x_pixels | y_pixels | min_value | rotation | best_fit_lat | best_fit_long |
-------|----------|----------|-----------|----------|--------------|---------------|
160148 |   141    |   208    |   707.67  |     3.18 |     34.66    |    -119.72    |

Running Against New Data

1) First select approximately 72 overlapping images from the flight you wish to identify.  These images should be in a more or less rectangular pattern.

2) These images should be converted from .tif to .jpg format by using the TopoCompare.prep_photos() function.  Remove any border from the boundary of the image by specifying *_crop parameters.

3) Use COLMAP to reconstruct the 3-dimensional rendering of the images.  For our project we used COLMAP 3.6-dev.3, but a newer versin may be available now.  We selected Reconstruction > Automatic reconstruction, specified an appropriate work folder and the correct images folder, and left all other parameters as default.  This process took approximately 2 hours on a NVIDIA GTX 1070.

4) Export the points3D.txt file and images.txt file by selecting File > Export model as text.

**!!WARNING!!** This step will take approximately 6 hours to complete on a home desktop.  This time is mostly spent in the pixelwise search.  

5) Direct the mhnc, df_diff, df_min = TopoCompare.topo_compare() function to the correct images_loc and points_loc as just exported from the COLMAP reconstruction.  
- Specify the number of pics in the x direction and y direction. 
- Indicate the scale (i.e. a scale of 1:20000 would have scale = 20000).
- Enter state as "California" (the only supported state to search at this time).
- Enter the height and width (in inches) of the cropped images from step (2).
- Specify num_matches if desired (default is 15).
- Ensure that **demo == False**.  This will ensure that all of California is searched.

6) View df_min to see results.


## Pix2pix Generative Adversarial Network

The git repository is not large enough to store all of the training images needed to recreate the GAN models from our paper. However we have included a zipped repository of Jun-Yan Zhu one of the authors of the original pix2pix GAN paper, which is easier to use than Philip Isola’s repo. All the jupyter notebooks and scripts needed to train and test a pix2pix GAN is included in the zip. Recall that pix2pix is a conditional GAN and reqires paired input images, so the zip has a script to join training and target images into a single input file for the pix2pix. For our purposes we joined the aerial images and the matching satellite images. When joining images they need to be the same dimensions (same size, number of channels and, type), so some reformatting may need to be done. Two good options for reformatting images are the Pillow and GDAL packages; Pillow is standard with Anaconda installs and GDAL must be either pip or conda installed.  Some of our images were in unusual formats that Pillow could not open however GDAL was able to handle conversion of these files to more standard formats. To run the join script you will have to first make A and B directories each with train, test, and val sub directories. To make it easy, put the input images into the A folders and the target images into the B folders so that you can train in the AtoB direction.

The training script is capable of running on multiple GPU’s and batching images really helps to speed things up. Using checkpoints will allow you to resume training from your last checkpoint if interrupted. This can be very useful, especially when training cycle GANs as they take quite a bit longer than pix2pix GANs. The models are designed to be trained on either Nvidia GPUs or a CPU but, we have not tried training on CPUs. Even though the GANs were not useful for this project, they are facinating and are worth further investigation.

