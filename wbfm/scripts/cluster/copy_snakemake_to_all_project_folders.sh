the full code is this:
#!/bin/bash
# Opens tmux session and runs snakemake for all projects in a folder. Example dry run usage:
# bash run_all_projects_in_parent_folder.sh -t '/path/to/parent/folder' -n True
#
# For real usage, remove '-n True' and update the path after -t
#

# Define the path to copy the "snakemake" folder from
SNAKEMAKE_SOURCE_PATH="/lisc/scratch/neurobiology/zimmer/ItamarLev/feedback_story/WBFM/get_traces/snakemake_barlow_defaults"

# Add help function
function usage {
  echo "Usage: $0 [-t folder_of_projects] [-n] [-d] [-s rule] [-h]"
  echo "  -t: folder of projects (required)"
  echo "  -n: dry run of this script (default: false)"
  echo "  -d: dry run of snakemake (default: false)"
  echo "  -s: snakemake rule to run (default: traces_and_behavior; other options: traces, behavior)"
  echo "  -h: display help (this message)"
  exit 1
}

RULE="traces_and_behavior"
is_dry_run=""
RUNME_ARGS=""

# Get all user flags
while getopts t:n:s:d:ch flag
do
    case "${flag}" in
        t) folder_of_projects=${OPTARG};;
        n) is_dry_run="True";;
        d) is_snakemake_dry_run=${OPTARG};;
        c) RUNME_ARGS="-c";;
        s) RULE=${OPTARG};;
        h) usage;;
        *) echo "Unknown flag"; usage;;
    esac
done

# Check if the selected rule is implemented
if [[ "$RULE" == "traces" ]] || [[ "$RULE" == "behavior_and_traces" ]]; then
    echo "Warning: '$RULE' option is not yet implemented. Please choose another rule."
    exit 1
fi

# Shared setup for each command
conda_setup_cmd="conda activate /lisc/scratch/neurobiology/zimmer/.conda/envs/wbfm/"

# Loop through the parent folder and check for subfolders with "_BH" in their names
for f in "$folder_of_projects"/*; do
    # Skip folders that contain "background" in their name
    if [[ $(basename "$f") == "background" ]]; then
        echo "Skipping: $f contains 'background' in its name."
        continue
    fi

    if [ -d "$f" ] && [ ! -L "$f" ]; then
        has_bh_subfolder=false

        # Check if any subfolder has "_BH" in its name
        for subfolder in "$f"/*; do
            if [ -d "$subfolder" ] && [[ $(basename "$subfolder") == _BH ]]; then
                has_bh_subfolder=true
                break
            fi
        done

        if [ "$has_bh_subfolder" = true ]; then
            echo "Valid project folder found: $f"

            # Copy specific files to the "snakemake" folder within the project directory
            snakemake_folder="$f/snakemake"

            # Define the specific files to replace
            files_to_replace=("pipeline.smk" "snakemake_config.yaml" "cluster_config.yaml")

            # Loop through the specific files and copy them if they don't already exist
            for file in "${files_to_replace[@]}"; do
                file_to_copy="$SNAKEMAKE_SOURCE_PATH/$file"
                destination_file="$snakemake_folder/$file"

                # Check if the file already exists and replace it if needed
                if [ -f "$destination_file" ]; then
                    echo "Replacing existing file: $file in $snakemake_folder"
                    cp "$file_to_copy" "$destination_file"
                else
                    echo "Copying file: $file to $snakemake_folder"
                    cp "$file_to_copy" "$destination_file"
                fi
            done

            if [ "$is_dry_run" ]; then
                echo "DRYRUN: Would run Snakemake on project: $f"
            else
                snakemake_script_path="$snakemake_folder/RUNME.sh"
                snakemake_cmd="$snakemake_script_path -s $RULE $RUNME_ARGS"
                if [ "$is_snakemake_dry_run" ]; then
                    snakemake_cmd="$snakemake_cmd -n"
                    echo "Running snakemake dry run"
                fi

                cd "$snakemake_folder" || exit
                JOB_NAME=$(basename "$f")
                JOB_NAME="${JOB_NAME}_${RULE}"
                echo "Running job with name: $JOB_NAME"

                if [ "$RUNME_ARGS" = "-c" ]; then
                    echo "Running locally: $snakemake_cmd"
                    bash $snakemake_cmd &
                else
                    full_cmd="$conda_setup_cmd; bash $snakemake_cmd"
                    sbatch --time 5-00:00:00 \
                        --cpus-per-task 1 \
                        --mem 1G \
                        --mail-type=FAIL,TIME_LIMIT,END \
                        --wrap="$full_cmd" \
                        --job-name="$JOB_NAME"
                fi
            fi
        else
            echo "Skipping: $f does not contain any subfolder with '_BH' in its name."
        fi
    fi
done