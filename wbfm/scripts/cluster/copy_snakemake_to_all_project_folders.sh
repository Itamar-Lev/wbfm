#!/bin/bash

################################################################################
# Script to copy Snakemake pipeline files to all valid project folders
#
# Usage:
#  bash ./copy_snakemake_files.sh -s /path/to/default_snakemake -p /path/to/root_folder
#
# Example:
#  bash /lisc/scratch/neurobiology/zimmer/wbfm/code/wbfm/wbfm/scripts/cluster/copy_snakemake_to_all_project_folders.sh -s /lisc/scratch/neurobiology/zimmer/wbfm/code/wbfm/wbfm/new_project_defaults/snakemake -p /lisc/scratch/neurobiology/zimmer/ItamarLev/WBFM/WBFM_projects/mutant_screen_3per
#
# The script will:
#   - Find all project folders under root_folder that contain a "snakemake" folder
#   - Report every valid project folder found
#   - Copy specific files from the default snakemake folder into each project's
#     snakemake folder
#   - Print a summary at the end
################################################################################

# Parse named options
while getopts "s:p:" opt; do
  case ${opt} in
    s )
      default_snakemake_folder="$OPTARG"
      ;;
    p )
      root_folder="$OPTARG"
      ;;
    \? )
      echo "Invalid option: -$OPTARG" 1>&2
      exit 1
      ;;
    : )
      echo "Option -$OPTARG requires an argument." 1>&2
      exit 1
      ;;
  esac
done

# Check if both options were provided
if [ -z "$default_snakemake_folder" ] || [ -z "$root_folder" ]; then
    echo "Usage: $0 -s <default_snakemake_folder_path> -p <root_folder_path>"
    exit 1
fi

# Predefined files to copy from default_snakemake_folder
files_to_copy=("RUNME.sh" "pipeline.smk" "cluster_config.yaml" "snakemake_config.yaml")

# Initialize counters
valid_projects=0
total_copied_files=0

# Function to copy files to snakemake folder
copy_files_to_snakemake() {
    local snakemake_folder="$1"
    local copied_this_project=0
    for file in "${files_to_copy[@]}"; do
        src="${default_snakemake_folder}/${file}"
        dest="${snakemake_folder}/${file}"
        if [ -f "${src}" ]; then
            cp "${src}" "${dest}"
            ((copied_this_project++))
        else
            echo "  ⚠️  Warning: File ${file} not found in ${default_snakemake_folder}"
        fi
    done
    total_copied_files=$((total_copied_files + copied_this_project))
}

echo "🔍 Searching for valid project folders under: ${root_folder}"
echo

# Find all valid project folders with a "snakemake" folder inside
while read -r snakemake_folder; do
    project_folder="$(dirname "${snakemake_folder}")"
    if [ -d "${project_folder}" ]; then
        ((valid_projects++))
        echo "✅ Found valid project folder: ${project_folder}"
        copy_files_to_snakemake "${snakemake_folder}"
    fi
done < <(find "${root_folder}" -type d -name "snakemake")

# Print summary
echo
echo "📄 Summary"
echo "----------------------------"
echo "Total valid project folders found: ${valid_projects}"
echo "Total files copied: ${total_copied_files}"
echo "Copied files: ${files_to_copy[*]}"
echo "From: ${default_snakemake_folder}"
