#!/bin/bash

# Check if directory path is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <directory_path>"
    exit 1
fi

DIR_PATH="$1"

# Check if directory exists
if [ ! -d "$DIR_PATH" ]; then
    echo "Error: Directory $DIR_PATH does not exist"
    exit 1
fi

# Create a temporary file list
TEMP_LIST=$(mktemp)

# Find all .ts files and sort them in reverse order
find "$DIR_PATH" -name "*.ts" -type f | sort -nr > "$TEMP_LIST"

# Check if any .ts files were found
if [ ! -s "$TEMP_LIST" ]; then
    echo "No .ts files found in $DIR_PATH"
    rm "$TEMP_LIST"
    exit 1
fi

# Create the concat file format that ffmpeg expects
CONCAT_FILE=$(mktemp)
while IFS= read -r file; do
    echo "file '$file'" >> "$CONCAT_FILE"
done < "$TEMP_LIST"

# Get the output filename from the directory name
OUTPUT_NAME=$(basename "$DIR_PATH")
OUTPUT_FILE="${DIR_PATH}/${OUTPUT_NAME}.mp4"

# Merge files using ffmpeg with VAAPI
sudo ffmpeg -f concat -safe 0 -i "$CONCAT_FILE" \
    -vaapi_device /dev/dri/renderD128 \
    -vf 'format=nv12,hwupload,scale_vaapi=w=-2:h=1080' \
    -c:v hevc_vaapi \
    -qp 27 \
    -c:a copy \
    "$OUTPUT_FILE"

# Remove .ts files if ffmpeg was successful
if [ $? -eq 0 ]; then
    echo "Removing source .ts files..."
    find "$DIR_PATH" -name "*.ts" -type f -delete
    echo "Source .ts files removed successfully"
fi

# Clean up temporary files
rm "$TEMP_LIST" "$CONCAT_FILE"

echo "Merged file saved as: $OUTPUT_FILE" 