#!/bin/bash

################################################################################
# Lato Font Installation Script for macOS
# 
# Installs fonts to user's font directory for immediate availability
# without requiring system restarts or cache clearing.
# 
# Deployment: Microsoft Intune as shell script (user context)
# Target Directory: ~/Library/Fonts/ (user-level installation)
# Execution Context: Runs as current user during Intune deployment
################################################################################

set -e
set -u

# Configuration variables
GITHUB_BASE_URL="https://raw.githubusercontent.com/cactuslifesciences/IntunePub/main/Fonts/Lato"
TEMP_DIR=$(mktemp -d -t lato-fonts)
FONT_INSTALL_DIR="${HOME}/Library/Fonts"
LOG_DIR="${HOME}/.logs"
LOG_FILE="${LOG_DIR}/lato_install_$(date '+%Y%m%d_%H%M%S').log"

# Lato font files to download
FONT_FILES=(
    "Lato-Black.ttf"
    "Lato-BlackItalic.ttf"
    "Lato-Bold.ttf"
    "Lato-BoldItalic.ttf"
    "Lato-Italic.ttf"
    "Lato-Light.ttf"
    "Lato-LightItalic.ttf"
    "Lato-Regular.ttf"
    "Lato-Thin.ttf"
    "Lato-ThinItalic.ttf"
)

################################################################################
# Logging function
################################################################################
log_message() {
    local level="${2:-INFO}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="[${timestamp}] [${level}] $1"
    echo "${message}" | tee -a "${LOG_FILE}"
}

################################################################################
# Error handler
################################################################################
cleanup_on_error() {
    log_message "Installation failed. Cleaning up temporary files..." "ERROR"
    rm -rf "${TEMP_DIR}"
    exit 1
}

trap cleanup_on_error ERR

################################################################################
# Main installation
################################################################################

# Create log directory
mkdir -p "${LOG_DIR}"

log_message "Starting Lato font installation"
log_message "Source: ${GITHUB_BASE_URL}"
log_message "Target: ${FONT_INSTALL_DIR}"
log_message "Temp directory: ${TEMP_DIR}"

# Ensure user Fonts directory exists
mkdir -p "${FONT_INSTALL_DIR}"
mkdir -p "${TEMP_DIR}"

# Download each font file
SUCCESS_COUNT=0
FAILED_COUNT=0

for font_file in "${FONT_FILES[@]}"; do
    download_url="${GITHUB_BASE_URL}/${font_file}"
    temp_file="${TEMP_DIR}/${font_file}"
    final_file="${FONT_INSTALL_DIR}/${font_file}"
    
    log_message "Downloading: ${font_file}"
    
    if curl -L -o "${temp_file}" "${download_url}" --silent --show-error --fail; then
        # Verify file exists and has content
        if [ -f "${temp_file}" ] && [ -s "${temp_file}" ]; then
            file_size=$(stat -f%z "${temp_file}" 2>/dev/null || echo "0")
            
            if [ "${file_size}" -gt 10000 ]; then
                # Copy to final location
                ditto "${temp_file}" "${final_file}"
                
                # Remove quarantine attribute
                xattr -d com.apple.quarantine "${final_file}" 2>/dev/null || true
                
                # Set permissions
                chmod 644 "${final_file}"
                
                log_message "Installed: ${font_file} ($(echo "scale=2; ${file_size}/1024" | bc) KB)"
                SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            else
                log_message "Failed: ${font_file} (file too small: ${file_size} bytes)" "ERROR"
                FAILED_COUNT=$((FAILED_COUNT + 1))
            fi
        else
            log_message "Failed: ${font_file} (file not created or empty)" "ERROR"
            FAILED_COUNT=$((FAILED_COUNT + 1))
        fi
    else
        log_message "Failed to download: ${font_file}" "ERROR"
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
done

# Force Font Book to validate
log_message "Refreshing font cache..."
killall "Font Book" 2>/dev/null || true
sleep 0.5
killall fontd 2>/dev/null || true
sleep 0.5

touch "${FONT_INSTALL_DIR}"
/System/Library/Frameworks/ApplicationServices.framework/Frameworks/ATS.framework/Support/fontrestore default -n 2>/dev/null || true

# Cleanup
log_message "Cleaning up temporary files..."
rm -rf "${TEMP_DIR}"

# Summary
log_message "Installation Summary:"
log_message "  - Successful: ${SUCCESS_COUNT}"
log_message "  - Failed: ${FAILED_COUNT}"
log_message "  - Total: ${#FONT_FILES[@]}"

if [ "${FAILED_COUNT}" -eq 0 ]; then
    log_message "Font installation completed successfully"
    exit 0
else
    log_message "Font installation completed with errors" "WARNING"
    exit 1
fi
