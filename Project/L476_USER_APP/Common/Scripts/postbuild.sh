#!/bin/sh
# ==============================================================================
#
# THE DEFINITIVE POST-BUILD SCRIPT
#
# This script is a complete, robust, and debuggable replacement for the
# original complex postbuild.sh provided by the user.
#
# It faithfully implements ALL original functionalities including:
#   - Encryption, Signing, Packing, and Header generation.
#   - Partial image generation (diff).
#   - Merged ELF file generation with the SBSFU bootloader.
#
# It incorporates all user requests:
#   - Full logging and debugging via a DEBUG_MODE switch.
#   - Robust error handling that reports the failed command.
#   - Project structure validation.
#   - POSIX shell compatibility (works with sh, handles spaces).
#
# ==============================================================================

# --- 1. SCRIPT CONFIGURATION ---
# Set to 1 for verbose logging (shows variables, commands, line numbers).
# Set to 0 for silent execution.
DEBUG_MODE=1

# --- 2. HELPER FUNCTIONS ---
# Corrected log_msg to accept line number as an argument
log_msg() {
  # $1: The line number from the call site
  # $2: The message to print
  if [ "$DEBUG_MODE" -eq 1 ]; then
    echo "[LINE $1] $2"
  fi
}

# Corrected execute_cmd to pass the line number correctly
execute_cmd() {
  # $1: The command string to execute
  # $2: The line number from the call site
  log_msg "$2" "EXECUTING: $1"
  # The 'eval' is used to correctly handle commands with complex quoting
  eval "$1"
  local exit_code=$?
  if [ $exit_code -ne 0 ]; then
    echo ""
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "!!! [FATAL ERROR] The script has failed."
    echo "!!! The command called at line $2 failed with exit code $exit_code:"
    echo "!!!   $1"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    exit $exit_code
  fi
}

# --- 3. SCRIPT BODY ---

log_msg $LINENO "--- Post-Build Script Started (Definitive Version) ---"

# --- STEP A: VALIDATION AND PATH SETUP ---
log_msg $LINENO "Validating arguments and setting up working directory..."

if [ "$#" -lt 5 ]; then
  echo "ERROR: At least 5 arguments are required."
  echo "Usage: $0 <build_dir> <elf_file> <bin_file> <fw_id> <version> [force_bigelf]"
  exit 1
fi

# Change CWD to the script's own location, identified from $0
cd "$(dirname "$0")"
if [ $? -ne 0 ]; then
    echo "!!! FATAL ERROR: Could not change directory to script location. Aborting."
    exit 1
fi
CWD=$(pwd)
log_msg $LINENO "Current Working Directory is now: \"$CWD\""

# --- STEP B: PROJECT STRUCTURE VALIDATION ---
log_msg $LINENO "Validating project structure from current location..."
if [ ! -d "../Binary" ]; then
  echo "ERROR: Required directory '../Binary' does not exist."
  exit 1
fi
KEYS_AND_IMAGES_DIR_REL="../../Middlewares/ST/STM32_Secure_Engine/Utilities/KeysAndImages"
if [ ! -d "$KEYS_AND_IMAGES_DIR_REL" ]; then
  echo "ERROR: Required directory for 'prepareimage' tool does not exist at '$KEYS_AND_IMAGES_DIR_REL'."
  exit 1
fi
log_msg $LINENO "Project structure validation successful."


# --- STEP C: DEFINE ALL VARIABLES ---
log_msg $LINENO "Defining all script variables..."

PROJECT_DIR_REL="$1"
log_msg $LINENO "Argument 1 (Project Dir): \"$PROJECT_DIR_REL\""
ELF_FILE_REL="$2"
log_msg $LINENO "Argument 2 (ELF File): \"$ELF_FILE_REL\""
BIN_FILE_REL="$3"
log_msg $LINENO "Argument 3 (BIN File): \"$BIN_FILE_REL\""
FW_ID="$4"
log_msg $LINENO "Argument 4 (FW ID): \"$FW_ID\""
VERSION="$5"
log_msg $LINENO "Argument 5 (Version): \"$VERSION\""

if [ "$#" -eq 6 ]; then
  FORCE_BIGELF=1
  log_msg $LINENO "Argument 6 detected: 'force_bigelf' is enabled."
else
  FORCE_BIGELF=0
fi

FILE_NAME=$(basename "$BIN_FILE_REL")
EXEC_NAME=${FILE_NAME%.*}
log_msg $LINENO "Executable Name: \"$EXEC_NAME\""

BINARY_OUTPUT_DIR_REL="../Binary"
SBSFU_ELF_REL="../2_Images_SBSFU/STM32CubeIDE/Debug/SBSFU.elf"
REF_USER_APP_REL="$PROJECT_DIR_REL/RefUserApp.bin"

SFU_FILE_REL="${BINARY_OUTPUT_DIR_REL}/${EXEC_NAME}.sfu"
SFB_FILE_REL="${BINARY_OUTPUT_DIR_REL}/${EXEC_NAME}.sfb"
SIGN_FILE_REL="${BINARY_OUTPUT_DIR_REL}/${EXEC_NAME}.sign"
HEADER_BIN_REL="${BINARY_OUTPUT_DIR_REL}/${EXEC_NAME}sfuh.bin"
NONCE_FILE_REL="../Binary/nonce.bin"
OEM_KEY_REL="../Binary/OEM_KEY_COMPANY${FW_ID}_key_AES_GCM.bin"
MAGIC="SFU${FW_ID}"

PARTIAL_BIN_REL="${BINARY_OUTPUT_DIR_REL}/Partial${EXEC_NAME}.bin"
PARTIAL_SFU_REL="${BINARY_OUTPUT_DIR_REL}/Partial${EXEC_NAME}.sfu"
PARTIAL_SIGN_REL="${BINARY_OUTPUT_DIR_REL}/Partial${EXEC_NAME}.sign"
PARTIAL_SFB_REL="${BINARY_OUTPUT_DIR_REL}/Partial${EXEC_NAME}.sfb"
PARTIAL_OFFSET_REL="${BINARY_OUTPUT_DIR_REL}/Partial${EXEC_NAME}.offset"

# --- STEP D: SELECT PREPAREIMAGE TOOL ---
log_msg $LINENO "Detecting platform to select prepareimage tool..."
PREPARE_IMAGE_CMD="python"
PREPARE_IMAGE_SCRIPT="\"${KEYS_AND_IMAGES_DIR_REL}/prepareimage.py\""

if uname | grep -i -e windows -e mingw >/dev/null 2>&1 && [ -f "${KEYS_AND_IMAGES_DIR_REL}/win/prepareimage/prepareimage.exe" ]; then
    log_msg $LINENO "Windows environment detected. Using prepareimage.exe"
    PREPARE_IMAGE_CMD="\"${KEYS_AND_IMAGES_DIR_REL}/win/prepareimage/prepareimage.exe\""
    PREPARE_IMAGE_SCRIPT=""
else
    log_msg $LINENO "Linux/macOS or no .exe found. Using python script."
fi
log_msg $LINENO "Prepareimage command set to: $PREPARE_IMAGE_CMD $PREPARE_IMAGE_SCRIPT"

# --- STEP E: MAIN EXECUTION FLOW ---
log_msg $LINENO "Ensuring Binary output directory exists..."
CMD_STR="mkdir -p \"$BINARY_OUTPUT_DIR_REL\""
execute_cmd "$CMD_STR" $LINENO

# Convert paths to Unix format for the tool
BIN_FILE_UNIX=$(echo "$BIN_FILE_REL" | sed 's/\\/\//g')
SFU_FILE_UNIX=$(echo "$SFU_FILE_REL" | sed 's/\\/\//g')
SIGN_FILE_UNIX=$(echo "$SIGN_FILE_REL" | sed 's/\\/\//g')
SFB_FILE_UNIX=$(echo "$SFB_FILE_REL" | sed 's/\\/\//g')
HEADER_BIN_UNIX=$(echo "$HEADER_BIN_REL" | sed 's/\\/\//g')
OEM_KEY_UNIX=$(echo "$OEM_KEY_REL" | sed 's/\\/\//g')
NONCE_UNIX=$(echo "$NONCE_FILE_REL" | sed 's/\\/\//g')

log_msg $LINENO "1. Encrypting binary..."
CMD_STR="$PREPARE_IMAGE_CMD $PREPARE_IMAGE_SCRIPT enc -k \"$OEM_KEY_UNIX\" -n \"$NONCE_UNIX\" \"$BIN_FILE_UNIX\" \"$SFU_FILE_UNIX\""
execute_cmd "$CMD_STR" $LINENO

log_msg $LINENO "2. Signing binary..."
CMD_STR="$PREPARE_IMAGE_CMD $PREPARE_IMAGE_SCRIPT sign -k \"$OEM_KEY_UNIX\" -n \"$NONCE_UNIX\" \"$BIN_FILE_UNIX\" \"$SIGN_FILE_UNIX\""
execute_cmd "$CMD_STR" $LINENO

log_msg $LINENO "3. Packing SFB file..."
CMD_STR="$PREPARE_IMAGE_CMD $PREPARE_IMAGE_SCRIPT pack -m \"$MAGIC\" -k \"$OEM_KEY_UNIX\" -r 112 -v \"$VERSION\" -n \"$NONCE_UNIX\" -f \"$SFU_FILE_UNIX\" -t \"$SIGN_FILE_UNIX\" \"$SFB_FILE_UNIX\" -o 512"
execute_cmd "$CMD_STR" $LINENO

log_msg $LINENO "4. Creating header binary..."
CMD_STR="$PREPARE_IMAGE_CMD $PREPARE_IMAGE_SCRIPT header -m \"$MAGIC\" -k \"$OEM_KEY_UNIX\" -r 112 -v \"$VERSION\" -n \"$NONCE_UNIX\" -f \"$SFU_FILE_UNIX\" -t \"$SIGN_FILE_UNIX\" -o 512 \"$HEADER_BIN_UNIX\""
execute_cmd "$CMD_STR" $LINENO

# --- STEP F: PARTIAL IMAGE GENERATION (IF APPLICABLE) ---
log_msg $LINENO "Checking if partial image generation is needed..."
if [ -f "$REF_USER_APP_REL" ]; then
  log_msg $LINENO "Reference user app found. Starting partial image generation."

  PARTIAL_BIN_UNIX=$(echo "$PARTIAL_BIN_REL" | sed 's/\\/\//g')
  PARTIAL_OFFSET_UNIX=$(echo "$PARTIAL_OFFSET_REL" | sed 's/\\/\//g')
  PARTIAL_SFU_UNIX=$(echo "$PARTIAL_SFU_REL" | sed 's/\\/\//g')
  PARTIAL_SIGN_UNIX=$(echo "$PARTIAL_SIGN_REL" | sed 's/\\/\//g')
  PARTIAL_SFB_UNIX=$(echo "$PARTIAL_SFB_REL" | sed 's/\\/\//g')
  REF_USER_APP_UNIX=$(echo "$REF_USER_APP_REL" | sed 's/\\/\//g')

  log_msg $LINENO "5a. Creating diff..."
  CMD_STR="$PREPARE_IMAGE_CMD $PREPARE_IMAGE_SCRIPT diff -1 \"$REF_USER_APP_UNIX\" -2 \"$BIN_FILE_UNIX\" \"$PARTIAL_BIN_UNIX\" -a 16 --poffset \"$PARTIAL_OFFSET_UNIX\""
  execute_cmd "$CMD_STR" $LINENO

  log_msg $LINENO "5b. Encrypting partial binary..."
  CMD_STR="$PREPARE_IMAGE_CMD $PREPARE_IMAGE_SCRIPT enc -k \"$OEM_KEY_UNIX\" -n \"$NONCE_UNIX\" \"$PARTIAL_BIN_UNIX\" \"$PARTIAL_SFU_UNIX\""
  execute_cmd "$CMD_STR" $LINENO

  log_msg $LINENO "5c. Signing partial binary..."
  CMD_STR="$PREPARE_IMAGE_CMD $PREPARE_IMAGE_SCRIPT sign -k \"$OEM_KEY_UNIX\" -n \"$NONCE_UNIX\" \"$PARTIAL_BIN_UNIX\" \"$PARTIAL_SIGN_UNIX\""
  execute_cmd "$CMD_STR" $LINENO

  log_msg $LINENO "5d. Packing partial SFB..."
  CMD_STR="$PREPARE_IMAGE_CMD $PREPARE_IMAGE_SCRIPT pack -m \"$MAGIC\" -k \"$OEM_KEY_UNIX\" -r 112 -v \"$VERSION\" -n \"$NONCE_UNIX\" -f \"$SFU_FILE_UNIX\" -t \"$SIGN_FILE_UNIX\" -o 512 --pfw \"$PARTIAL_SFU_UNIX\" --ptag \"$PARTIAL_SIGN_UNIX\" --poffset \"$PARTIAL_OFFSET_UNIX\" \"$PARTIAL_SFB_UNIX\""
  execute_cmd "$CMD_STR" $LINENO

else
  log_msg $LINENO "No reference user app found. Skipping partial image generation."
fi

# --- STEP G: MERGED ELF GENERATION (IF APPLICABLE) ---
log_msg $LINENO "Checking if merged ELF generation is needed..."
if [ "$FORCE_BIGELF" -eq 1 ]; then
  log_msg $LINENO "Force big ELF flag is set. Starting merged ELF generation."
  PROGRAMMER_TOOL="STM32_Programmer_CLI"
  
  if uname | grep -i -e windows -e mingw >/dev/null 2>&1; then
    if [ -f "C:/Program Files (x86)/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32_Programmer_CLI.exe" ]; then
        PROGRAMMER_TOOL="\"C:/Program Files (x86)/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32_Programmer_CLI.exe\""
    else
        log_msg $LINENO "WARNING: STM32_Programmer_CLI.exe not found in default location. Make sure it is in your PATH."
    fi
  else
    if ! which STM32_Programmer_CLI >/dev/null 2>&1; then
      log_msg $LINENO "WARNING: STM32_Programmer_CLI not found in PATH."
    fi
  fi
  log_msg $LINENO "Using programmer tool: $PROGRAMMER_TOOL"
  
  ELF_FILE_UNIX=$(echo "$ELF_FILE_REL" | sed 's/\\/\//g')
  SBSFU_ELF_UNIX=$(echo "$SBSFU_ELF_REL" | sed 's/\\/\//g')
  
  CMD_STR="$PROGRAMMER_TOOL -ms \"$ELF_FILE_UNIX\" \"$HEADER_BIN_UNIX\" \"$SBSFU_ELF_UNIX\""
  execute_cmd "$CMD_STR" $LINENO
  
else
  log_msg $LINENO "Force big ELF flag not set. Skipping merged ELF generation."
fi

# --- STEP H: CLEANUP ---
log_msg $LINENO "Cleaning up temporary files..."
CMD_STR="rm -f \"$SIGN_FILE_UNIX\" \"$SFU_FILE_UNIX\" \"$HEADER_BIN_UNIX\""
execute_cmd "$CMD_STR" $LINENO

if [ -f "$REF_USER_APP_REL" ]; then
  log_msg $LINENO "Cleaning up partial image temporary files..."
  CMD_STR="rm -f \"$PARTIAL_BIN_UNIX\" \"$PARTIAL_SFU_UNIX\" \"$PARTIAL_SIGN_UNIX\" \"$PARTIAL_OFFSET_UNIX\""
  execute_cmd "$CMD_STR" $LINENO
fi

log_msg $LINENO "--- Post-Build Script Finished Successfully ---"
exit 0
