#!/bin/bash

# Default directories and files
DATA_DIR="."
OUTPUT_DIR="."
T1W_IMAGE=""
T2W_IMAGE=""

usage() {
echo "Usage: $0 [--data-dir DATA_DIR] [--output-dir OUTPUT_DIR] --t1w-image T1W_IMAGE --t2w-image T2W_IMAGE"
echo "  --data-dir DATA_DIR      : Directory containing input data (default: current directory)"
echo "  --output-dir OUTPUT_DIR  : Directory to save output (default: current directory)"
echo "  --t1w-image T1W_IMAGE    : T1-weighted image file (required)"
echo "  --t2w-image T2W_IMAGE    : T2-weighted image file (required)"
exit 1
}

# Parse command line options
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --data-dir)
      DATA_DIR="$2"
      shift # past argument
      shift # past value
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift
      shift
      ;;
    --t1w-image)
      T1W_IMAGE="$2"
      shift
      shift
      ;;
    --t2w-image)
      T2W_IMAGE="$2"
      shift
      shift
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

# Set positional arguments if T1W_IMAGE and T2W_IMAGE are not provided as options
if [[ -z "$T1W_IMAGE" && ${#POSITIONAL_ARGS[@]} -ge 1 ]]; then
  T1W_IMAGE="${POSITIONAL_ARGS[0]}"
fi

if [[ -z "$T2W_IMAGE" && ${#POSITIONAL_ARGS[@]} -ge 2 ]]; then
  T2W_IMAGE="${POSITIONAL_ARGS[1]}"
fi

# Check if T1W_IMAGE and T2W_IMAGE are set
if [[ -z "$T1W_IMAGE" || -z "$T2W_IMAGE" ]]; then
echo "Error: T1W_IMAGE and T2W_IMAGE are required."
usage
fi

# Print values to verify
echo "Data Directory: $DATA_DIR"
echo "Output Directory: $OUTPUT_DIR"
echo "T1-weighted Image: $T1W_IMAGE"
echo "T2-weighted Image: $T2W_IMAGE"

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
fslmaths ${OUTPUT_DIR}/${T1W_BASENAME}bias_corrected.nii.gz -mas ${OUTPUT_DIR}/${T1W_BASENAME}brain_mask_bin.nii.gz ${OUTPUT_DIR}/${T1W_BASENAME}bias_corrected_brain.nii.gz


# Step 4: White and gray matter segmentation using FSL FAST
echo "Step 4: White and gray matter segmentation using FSL FAST..."
fast -t 1 -n 3 -H 0.1 -I 4 -l 20.0 -o ${OUTPUT_DIR}/${T1W_BASENAME}segmented ${OUTPUT_DIR}/${T1W_BASENAME}bias_corrected_brain.nii.gz



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
fslmaths ${OUTPUT_DIR}/${T1W_BASENAME}T1w_sub_sT2w.nii.gz -div ${OUTPUT_DIR}/${T1W_BASENAME}T1w_plus_sT2w.nii.gz   ${OUTPUT_DIR}/${T1W_BASENAME}_T1T2ratio.nii.gz


# Step 8: Mask out the sT1w/T2w ratio map using the brain mask
echo "Step 8: Masking out the sT1w/T2w ratio map using the brain mask..."
fslmaths ${OUTPUT_DIR}/${T1W_BASENAME}_T1T2ratio.nii.gz -mas ${OUTPUT_DIR}/${T1W_BASENAME}brain_mask_bin.nii.gz ${OUTPUT_DIR}/${T1W_BASENAME}_T1T2ratio_brain.nii.gz


# Step 9: Calc mean T1/sT2 ration  within GM,WM
echo "Step 9: Masking out the sT1w/T2w ratio map using the brain mask..."

Ratio_GM_MEDIAN=$(fslstats ${OUTPUT_DIR}/${T1W_BASENAME}_T1T2ratio.nii.gz -k ${OUTPUT_DIR}/${T1W_BASENAME}segmented_pve_1.nii.gz -P 50)
Ratio_WM_MEDIAN=$(fslstats ${OUTPUT_DIR}/${T1W_BASENAME}_T1T2ratio.nii.gz  -k ${OUTPUT_DIR}/${T1W_BASENAME}segmented_pve_2.nii.gz -P 50)
Ratio_GM_MEAN=$(fslstats ${OUTPUT_DIR}/${T1W_BASENAME}_T1T2ratio.nii.gz -k ${OUTPUT_DIR}/${T1W_BASENAME}segmented_pve_1.nii.gz -M )
Ratio_WM_MEAN=$(fslstats ${OUTPUT_DIR}/${T1W_BASENAME}_T1T2ratio.nii.gz  -k ${OUTPUT_DIR}/${T1W_BASENAME}segmented_pve_2.nii.gz -M )

#output csv
echo "T1name,Scaling Factor,GM_Mean,WM_Mean,GM_Median,WM_Median" > ${OUTPUT_DIR}/${T1W_BASENAME}_T1T2ratio.csv
echo "${T1W_BASENAME},$SCALING_FACTOR,$Ratio_GM_MEAN,$Ratio_WM_MEAN,$Ratio_GM_MEDIAN,$Ratio_WM_MEDIAN" >> ${OUTPUT_DIR}/${T1W_BASENAME}_T1T2ratio.csv
