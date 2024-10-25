#!/bin/bash

# Directories
DATA_DIR="/home/maikusa/T1T2_Proc"
OUTPUT_DIR="/home/maikusa/T1T2_Proc"
T1W_IMAGE="sub-CSUB-00001C-01_T1w.nii.gz"
T2W_IMAGE="sub-CSUB-00001C-01_FLAIR.nii.gz"

# Get basenames without extensions for T1W and T2W images
T1W_BASENAME=$(basename ${T1W_IMAGE} .nii.gz)_
T2W_BASENAME=$(basename ${T2W_IMAGE} .nii.gz)_

# Step 1: Intensity inhomogeneity correction
echo "Step 1: Intensity inhomogeneity correction..."
N4BiasFieldCorrection -i ${DATA_DIR}/${T1W_IMAGE} -o ${OUTPUT_DIR}/${T1W_BASENAME}corrected.nii.gz
N4BiasFieldCorrection -i ${DATA_DIR}/${T2W_IMAGE} -o ${OUTPUT_DIR}/${T2W_BASENAME}corrected.nii.gz

# Step 2: Linear co-registration of T2w to T1w image using ANTs
echo "Step 2: Linear co-registration of T2w to T1w image using ANTs..."
antsRegistration --dimensionality 3 \
  --output [${OUTPUT_DIR}/${T2W_BASENAME}to_T1w_,${OUTPUT_DIR}/${T2W_BASENAME}to_T1w_Warped.nii.gz] \
  --interpolation Linear \
  --winsorize-image-intensities [0.005,0.995] \
  --initial-moving-transform [${OUTPUT_DIR}/${T1W_BASENAME}corrected.nii.gz,${OUTPUT_DIR}/${T2W_BASENAME}corrected.nii.gz,1] \
  --transform Rigid[0.1] \
  --metric MI[${OUTPUT_DIR}/${T1W_BASENAME}corrected.nii.gz,${OUTPUT_DIR}/${T2W_BASENAME}corrected.nii.gz,1,32,Regular,0.25] \
  --convergence [1000x500x250x0,1e-6,10] \
  --shrink-factors 8x4x2x1 \
  --smoothing-sigmas 3x2x1x0vox

# Step 3: Skull-stripping T1w image and binarizing using FSL
echo "Step 3: Skull-stripping T1w image and binarizing using FSL..."
bet ${OUTPUT_DIR}/${T1W_BASENAME}corrected.nii.gz ${OUTPUT_DIR}/${T1W_BASENAME}brain_mask.nii.gz -R
fslmaths ${OUTPUT_DIR}/${T1W_BASENAME}brain_mask.nii.gz -bin ${OUTPUT_DIR}/${T1W_BASENAME}brain_mask_bin.nii.gz

# Step 3.1: Bias field correction using BiasFieldCorrection_sqrtT1wXT2w.sh
echo "Step 3.1: Bias field correction using BiasFieldCorrection_sqrtT1wXT2w.sh..."
BiasFieldCorrection_sqrtT1wXT2w.sh --T1im=${OUTPUT_DIR}/${T1W_BASENAME}corrected.nii.gz --T1brain=${OUTPUT_DIR}/${T1W_BASENAME}brain_mask_bin.nii.gz --T2im=${OUTPUT_DIR}/${T2W_BASENAME}to_T1w_Warped.nii.gz --oT1im ${OUTPUT_DIR}/${T1W_BASENAME}bias_corrected.nii.gz  --oT1brain=${OUTPUT_DIR}/${T1W_BASENAME}Brain_bias_corrected.nii.gz  --oT2im ${OUTPUT_DIR}/${T2W_BASENAME}bias_corrected_to_T1w_Warped.nii.gz --oT2brain=${OUTPUT_DIR}/${T2W_BASENAME}Brain_bias_corrected_to_T1w_Warped.nii.gz --obias=${T1W_BASENAME}BiasField.nii.gz



# Step 4: White and gray matter segmentation using FSL FAST
echo "Step 4: White and gray matter segmentation using FSL FAST..."
fast -t 1 -n 3 -H 0.1 -I 4 -l 20.0 -o ${OUTPUT_DIR}/${T1W_BASENAME}segmented ${OUTPUT_DIR}/${T1W_BASENAME}bias_corrected.nii.gz

# Step 5: Calculate median intensity values for white and gray matter masks
echo "Step 5: Calculate median intensity values for white and gray matter masks..."
T1W_GM_MEDIAN=$(fslstats ${OUTPUT_DIR}/${T1W_BASENAME}bias_corrected.nii.gz -k ${OUTPUT_DIR}/${T1W_BASENAME}segmented_pve_1.nii.gz -P 50)
T2W_GM_MEDIAN=$(fslstats ${OUTPUT_DIR}/${T2W_BASENAME}bias_corrected_to_T1w_Warped.nii.gz  -k ${OUTPUT_DIR}/${T1W_BASENAME}segmented_pve_1.nii.gz -P 50)


# Step 5.1: Resample T2w image to match T1w image dimensions (if necessary)
echo "Step 5.1: Resampling T2w image to match T1w image dimensions if needed..."
T1W_DIM=$(fslinfo ${OUTPUT_DIR}/${T1W_BASENAME}bias_corrected.nii.gz | grep dim1 | awk '{print $2}')
T2W_DIM=$(fslinfo ${OUTPUT_DIR}/${T2W_BASENAME}bias_corrected_to_T1w_Warped.nii.gz | grep dim1 | awk '{print $2}')
if [ "$T1W_DIM" != "$T2W_DIM" ]; then
  echo "Resampling T2w image to match T1w dimensions..."
  flirt -in ${OUTPUT_DIR}/${T2W_BASENAME}bias_corrected_to_T1w_Warped.nii.gz -ref ${OUTPUT_DIR}/${T1W_BASENAME}bias_corrected.nii.gz -out ${OUTPUT_DIR}/${T2W_BASENAME}resampled_bias_corrected_to_T1w_Warped.nii.gz
  T2W_IMAGE_TO_USE=${OUTPUT_DIR}/${T2W_BASENAME}resampled_bias_corrected_to_T1w_Warped.nii.gz
else
  T2W_IMAGE_TO_USE=${OUTPUT_DIR}/${T2W_BASENAME}bias_corrected_to_T1w_Warped.nii.gz
fi



# Step 6: Scaling factor calculation and scaled T2w image creation
echo "Step 6: Scaling factor calculation and scaled T2w image creation..."
#SCALING_FACTOR=$(echo "${T1W_GM_MEDIAN} / ${T2W_GM_MEDIAN}" | bc -l)
SCALING_FACTOR=$(awk "BEGIN {print ${T1W_GM_MEDIAN}/${T2W_GM_MEDIAN}}")
fslmaths ${T2W_IMAGE_TO_USE} -mul ${SCALING_FACTOR} ${OUTPUT_DIR}/${T2W_BASENAME}scaled.nii.gz
echo "Scaling Factor: ${SCALING_FACTOR}"

# Step 7: Calculate sT1w/T2w ratio
echo "Step 7: Calculate sT1w/T2w ratio..."
fslmaths ${OUTPUT_DIR}/${T1W_BASENAME}bias_corrected.nii.gz -add ${OUTPUT_DIR}/${T2W_BASENAME}scaled.nii.gz  ${OUTPUT_DIR}/${T1W_BASENAME}T1w_plus_sT2w.nii.gz
fslmaths ${OUTPUT_DIR}/${T1W_BASENAME}bias_corrected.nii.gz -sub ${OUTPUT_DIR}/${T2W_BASENAME}scaled.nii.gz  ${OUTPUT_DIR}/${T1W_BASENAME}T1w_sub_sT2w.nii.gz
fslmaths ${OUTPUT_DIR}/${T1W_BASENAME}T1w_sub_sT2w.nii.gz -div ${OUTPUT_DIR}/${T1W_BASENAME}T1w_plus_sT2w.nii.gz   ${OUTPUT_DIR}/${T1W_BASENAME}ratio_T1w_sT2w.nii.gz



# Step 8: Mask out the sT1w/T2w ratio map using the brain mask
echo "Step 8: Masking out the sT1w/T2w ratio map using the brain mask..."
fslmaths ${OUTPUT_DIR}/${T1W_BASENAME}ratio_T1w_sT2w.nii.gz -mas ${OUTPUT_DIR}/${T1W_BASENAME}brain_mask_bin.nii.gz ${OUTPUT_DIR}/${T1W_BASENAME}ratio_masked_T1w_sT2w.nii.gz