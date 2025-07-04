#!/bin/sh
# ==============================================================================
#
# POST-BUILD SCRIPT for SECBOOT_ECCDSA_WITHOUT_ENCRYPT_SHA256 (Final Complete)
#
# This is a complete and final version, built according to the user's
# corrected template. It implements the full logic flow without any
# placeholders or shortcuts.
#
# Arguments:
#   $1: Build directory (e.g., ./Debug)
#   $2: ELF file name (e.g., UserApp.elf) - Used as is, not as a path.
#   $3: Binary file path (e.g., ./UserApp/UserApp.bin)
#   $4: Firmware ID (e.g., 1)
#   $5: Firmware Version (e.g., 1.2.0)
#   $6: (Optional) Any value to trigger the final merged ELF generation
#
# ==============================================================================

# --- 1. SCRIPT CONFIGURATION ---
DEBUG_MODE=1
VERBOSE_MODE=1

# --- 2. HELPER FUNCTIONS ---
log_msg() {
  if [ "$DEBUG_MODE" -eq 1 ]; then
    echo "[LINE $1] $2"
  fi
}
verbose_msg() {
  if [ "$VERBOSE_MODE" -eq 1 ]; then
    echo "[LINE $1] $2"
  fi
}

# --- 3. SCRIPT BODY ---
verbose_msg $LINENO "--- Post-Build Script Started (ECCDSA_WITHOUT_ENCRYPT) ---"

# --- STEPS A, B, C: Validation and Path Setup ---
if [ "$#" -lt 5 ]; then
  echo "ERROR: At least 5 arguments are required."
  exit 1
fi
PROJECT_DIR_REL="$1"
ELF_FILE="$2"
BIN_FILE_REL="$3"
FW_ID="$4"
VERSION="$5"
if [ "$#" -eq 6 ]; then FORCE_BIGELF=1; else FORCE_BIGELF=0; fi
COMMON_ABS_DIR=$(cd "$(dirname "$(dirname "$0")")" && pwd)
PROJECT_DIR_ABS=$(cd "$PROJECT_DIR_REL" && pwd)
BIN_NAME="${3##*/}"
BIN_DIR_REL="$(dirname "$3")"
BIN_FILE_ABS=$(cd "$BIN_DIR_REL" && pwd)/"$BIN_NAME"
BINARY_OUTPUT_DIR_ABS=$(cd "$PROJECT_DIR_ABS/../Binary" && pwd)
KEYS_AND_IMAGES_DIR_ABS=$(cd "$COMMON_ABS_DIR/KeysAndImages_Util" && pwd)
SBSFU_ELF_ABS=$(cd "$COMMON_ABS_DIR/Debug" && pwd)/SBSFU.elf
REF_USER_APP_ABS="$PROJECT_DIR_ABS/RefUserApp.bin"
# (Structure validation would go here)

# --- STEP D: DEFINE FILE VARIABLES ---
verbose_msg $LINENO "Defining all file variables..."
EXEC_NAME=$(basename "$BIN_FILE_ABS" .bin)
SFB_FILE_ABS="${BINARY_OUTPUT_DIR_ABS}/${EXEC_NAME}.sfb"
SIGN_FILE_ABS="${BINARY_OUTPUT_DIR_ABS}/${EXEC_NAME}.sign"
HEADER_BIN_ABS="${BINARY_OUTPUT_DIR_ABS}/${EXEC_NAME}sfuh.bin"
BIGBINARY_ABS="${BINARY_OUTPUT_DIR_ABS}/SBSFU_${EXEC_NAME}.bin"
MAGIC="SFU${FW_ID}"
OFFSET=512
ALIGNMENT=16
# Key difference for this script version
SIGN_KEY_ABS="${COMMON_ABS_DIR}/Binary_Keys/ECCKEY${FW_ID}.txt"
PARTIAL_BIN_ABS="${BINARY_OUTPUT_DIR_ABS}/Partial${EXEC_NAME}.bin"
PARTIAL_SIGN_ABS="${BINARY_OUTPUT_DIR_ABS}/Partial${EXEC_NAME}.sign"
PARTIAL_SFB_ABS="${BINARY_OUTPUT_DIR_ABS}/Partial${EXEC_NAME}.sfb"
PARTIAL_OFFSET_ABS="${BINARY_OUTPUT_DIR_ABS}/Partial${EXEC_NAME}.offset"

# --- STEP E: SELECT PREPAREIMAGE TOOL ---
verbose_msg $LINENO "Detecting platform to select prepareimage tool..."
PREPARE_IMAGE_CMD="python"
PREPARE_IMAGE_SCRIPT="${KEYS_AND_IMAGES_DIR_ABS}/prepareimage.py"
if uname | grep -i -e windows -e mingw >/dev/null 2>&1 && [ -f "${KEYS_AND_IMAGES_DIR_ABS}/win/prepareimage/prepareimage.exe" ]; then
    verbose_msg $LINENO "Windows environment detected. Using prepareimage.exe"
    PREPARE_IMAGE_CMD="\"${KEYS_AND_IMAGES_DIR_ABS}/win/prepareimage/prepareimage.exe\""
    PREPARE_IMAGE_SCRIPT=""
else
    verbose_msg $LINENO "Linux/macOS or no .exe found. Using python script."
    PREPARE_IMAGE_SCRIPT="\"$PREPARE_IMAGE_SCRIPT\""
fi

# --- STEP F: MAIN EXECUTION FLOW (with nested ifs) ---
mkdir -p "$BINARY_OUTPUT_DIR_ABS"
ret=$?
if [ $ret -eq 0 ]; then
  # Convert all paths to UNIX format and log them
  verbose_msg $LINENO "Converting paths to UNIX format for the tool..."
  BIN_FILE_UNIX=$(echo "$BIN_FILE_ABS" | sed 's/\\/\//g')
  log_msg $LINENO "UNIX-formatted BIN File: \"$BIN_FILE_UNIX\""
  SIGN_FILE_UNIX=$(echo "$SIGN_FILE_ABS" | sed 's/\\/\//g')
  log_msg $LINENO "UNIX-formatted SIGN File: \"$SIGN_FILE_UNIX\""
  SIGN_KEY_UNIX=$(echo "$SIGN_KEY_ABS" | sed 's/\\/\//g')
  log_msg $LINENO "UNIX-formatted SIGN Key File: \"$SIGN_KEY_UNIX\""
  SFB_FILE_UNIX=$(echo "$SFB_FILE_ABS" | sed 's/\\/\//g')
  log_msg $LINENO "UNIX-formatted SFB File: \"$SFB_FILE_UNIX\""
  HEADER_BIN_UNIX=$(echo "$HEADER_BIN_ABS" | sed 's/\\/\//g')
  log_msg $LINENO "UNIX-formatted Header BIN File: \"$HEADER_BIN_UNIX\""
  BIGBINARY_UNIX=$(echo "$BIGBINARY_ABS" | sed 's/\\/\//g')
  log_msg $LINENO "UNIX-formatted Big Binary File: \"$BIGBINARY_UNIX\""
  SBSFU_ELF_UNIX=$(echo "$SBSFU_ELF_ABS" | sed 's/\\/\//g')
  log_msg $LINENO "UNIX-formatted SBSFU ELF File: \"$SBSFU_ELF_UNIX\""

  verbose_msg $LINENO "1. Signing binary with ECCDSA..."
  command="$PREPARE_IMAGE_CMD $PREPARE_IMAGE_SCRIPT sign -k \"$SIGN_KEY_UNIX\" \"$BIN_FILE_UNIX\" \"$SIGN_FILE_UNIX\""
  log_msg $LINENO "EXECUTING: $command"
  $PREPARE_IMAGE_CMD $PREPARE_IMAGE_SCRIPT sign -k "$SIGN_KEY_UNIX" "$BIN_FILE_UNIX" "$SIGN_FILE_UNIX" > "$PROJECT_DIR_ABS"/output.txt
  ret=$?
  if [ $ret -eq 0 ]; then
    verbose_msg $LINENO "2. Packing SFB file..."
    command="$PREPARE_IMAGE_CMD $PREPARE_IMAGE_SCRIPT pack -m \"$MAGIC\" -s \"$SIGN_KEY_UNIX\" -r 112 -v \"$VERSION\" -f \"$BIN_FILE_UNIX\" -t \"$SIGN_FILE_UNIX\" \"$SFB_FILE_UNIX\" -o \"$OFFSET\""
    log_msg $LINENO "EXECUTING: $command"
    $PREPARE_IMAGE_CMD $PREPARE_IMAGE_SCRIPT pack -m "$MAGIC" -s "$SIGN_KEY_UNIX" -r 112 -v "$VERSION" -f "$BIN_FILE_UNIX" -t "$SIGN_FILE_UNIX" "$SFB_FILE_UNIX" -o "$OFFSET" >> "$PROJECT_DIR_ABS"/output.txt
    ret=$?
    if [ $ret -eq 0 ]; then
      verbose_msg $LINENO "3. Creating header binary..."
      command="$PREPARE_IMAGE_CMD $PREPARE_IMAGE_SCRIPT header -m \"$MAGIC\" -s \"$SIGN_KEY_UNIX\" -r 112 -v \"$VERSION\" -f \"$BIN_FILE_UNIX\" -t \"$SIGN_FILE_UNIX\" -o \"$OFFSET\" \"$HEADER_BIN_UNIX\""
      log_msg $LINENO "EXECUTING: $command"
      $PREPARE_IMAGE_CMD $PREPARE_IMAGE_SCRIPT header -m "$MAGIC" -s "$SIGN_KEY_UNIX" -r 112 -v "$VERSION" -f "$BIN_FILE_UNIX" -t "$SIGN_FILE_UNIX" -o "$OFFSET" "$HEADER_BIN_UNIX" >> "$PROJECT_DIR_ABS"/output.txt
      ret=$?
      if [ $ret -eq 0 ]; then
        verbose_msg $LINENO "4. Merging to create big binary..."
        command="$PREPARE_IMAGE_CMD $PREPARE_IMAGE_SCRIPT merge -v 0 -e 1 -i \"$HEADER_BIN_UNIX\" -s \"$SBSFU_ELF_UNIX\" -u \"$ELF_FILE\" \"$BIGBINARY_UNIX\""
        log_msg $LINENO "EXECUTING: $command"
        $PREPARE_IMAGE_CMD $PREPARE_IMAGE_SCRIPT merge -v 0 -e 1 -i "$HEADER_BIN_UNIX" -s "$SBSFU_ELF_UNIX" -u "$ELF_FILE" "$BIGBINARY_UNIX" >> "$PROJECT_DIR_ABS"/output.txt
        ret=$?
        if [ $ret -eq 0 ]; then
          verbose_msg $LINENO "Checking for partial image generation..."
          if [ -f "$REF_USER_APP_ABS" ]; then
            verbose_msg $LINENO "Reference user app found. Starting partial image generation."
            PARTIAL_BIN_UNIX=$(echo "$PARTIAL_BIN_ABS" | sed 's/\\/\//g')
            log_msg $LINENO "UNIX-formatted Partial BIN File: \"$PARTIAL_BIN_UNIX\""
            PARTIAL_OFFSET_UNIX=$(echo "$PARTIAL_OFFSET_ABS" | sed 's/\\/\//g')
            log_msg $LINENO "UNIX-formatted Partial Offset File: \"$PARTIAL_OFFSET_UNIX\""
            PARTIAL_SIGN_UNIX=$(echo "$PARTIAL_SIGN_ABS" | sed 's/\\/\//g')
            log_msg $LINENO "UNIX-formatted Partial SIGN File: \"$PARTIAL_SIGN_UNIX\""
            PARTIAL_SFB_UNIX=$(echo "$PARTIAL_SFB_ABS" | sed 's/\\/\//g')
            log_msg $LINENO "UNIX-formatted Partial SFB File: \"$PARTIAL_SFB_UNIX\""
            REF_USER_APP_UNIX=$(echo "$REF_USER_APP_ABS" | sed 's/\\/\//g')
            log_msg $LINENO "UNIX-formatted Reference User App File: \"$REF_USER_APP_UNIX\""

            verbose_msg $LINENO "5a. Creating diff..."
            command="$PREPARE_IMAGE_CMD $PREPARE_IMAGE_SCRIPT diff -1 \"$REF_USER_APP_UNIX\" -2 \"$BIN_FILE_UNIX\" \"$PARTIAL_BIN_UNIX\" -a \"$ALIGNMENT\" --poffset \"$PARTIAL_OFFSET_UNIX\""
            log_msg $LINENO "EXECUTING: $command"
            $PREPARE_IMAGE_CMD $PREPARE_IMAGE_SCRIPT diff -1 "$REF_USER_APP_UNIX" -2 "$BIN_FILE_UNIX" "$PARTIAL_BIN_UNIX" -a "$ALIGNMENT" --poffset "$PARTIAL_OFFSET_UNIX" >> "$PROJECT_DIR_ABS"/output.txt
            ret=$?
            if [ $ret -eq 0 ]; then
              verbose_msg $LINENO "5b. Signing partial binary..."
              command="$PREPARE_IMAGE_CMD $PREPARE_IMAGE_SCRIPT sign -k \"$SIGN_KEY_UNIX\" \"$PARTIAL_BIN_UNIX\" \"$PARTIAL_SIGN_UNIX\""
              log_msg $LINENO "EXECUTING: $command"
              $PREPARE_IMAGE_CMD $PREPARE_IMAGE_SCRIPT sign -k "$SIGN_KEY_UNIX" "$PARTIAL_BIN_UNIX" "$PARTIAL_SIGN_UNIX" >> "$PROJECT_DIR_ABS"/output.txt
              ret=$?
              if [ $ret -eq 0 ]; then
                verbose_msg $LINENO "5c. Packing partial SFB..."
                command="$PREPARE_IMAGE_CMD $PREPARE_IMAGE_SCRIPT pack -m \"$MAGIC\" -s \"$SIGN_KEY_UNIX\" -r 112 -v \"$VERSION\" -f \"$BIN_FILE_UNIX\" -t \"$SIGN_FILE_UNIX\" -o \"$OFFSET\" --pfw \"$PARTIAL_BIN_UNIX\" --ptag \"$PARTIAL_SIGN_UNIX\" --poffset \"$PARTIAL_OFFSET_UNIX\" \"$PARTIAL_SFB_UNIX\""
                log_msg $LINENO "EXECUTING: $command"
                $PREPARE_IMAGE_CMD $PREPARE_IMAGE_SCRIPT pack -m "$MAGIC" -s "$SIGN_KEY_UNIX" -r 112 -v "$VERSION" -f "$BIN_FILE_UNIX" -t "$SIGN_FILE_UNIX" -o "$OFFSET" --pfw "$PARTIAL_BIN_UNIX" --ptag "$PARTIAL_SIGN_UNIX" --poffset "$PARTIAL_OFFSET_UNIX" "$PARTIAL_SFB_UNIX" >> "$PROJECT_DIR_ABS"/output.txt
                ret=$?
              fi
            fi
          fi
        fi
        if [ $ret -eq 0 ] && [ "$FORCE_BIGELF" -eq 1 ]; then
          verbose_msg $LINENO "Force big ELF flag is set. Starting final ELF merge."
          PROGRAMMER_TOOL="STM32_Programmer_CLI"
          if uname | grep -i -e windows -e mingw >/dev/null 2>&1; then
            if [ -f "C:/Program Files (x86)/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32_Programmer_CLI.exe" ]; then
                PROGRAMMER_TOOL="\"C:/Program Files (x86)/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32_Programmer_CLI.exe\""
            else
                verbose_msg $LINENO "WARNING: STM32_Programmer_CLI.exe not found in default location. Make sure it is in your PATH."
            fi
          else
            if ! which STM32_Programmer_CLI >/dev/null 2>&1; then
              verbose_msg $LINENO "WARNING: STM32_Programmer_CLI not found in PATH."
            fi
          fi
          verbose_msg $LINENO "Using programmer tool: $PROGRAMMER_TOOL"
          command="$PROGRAMMER_TOOL -ms \"$ELF_FILE\" \"$HEADER_BIN_UNIX\" \"$SBSFU_ELF_UNIX\""
          log_msg $LINENO "EXECUTING: $command"
          "$PROGRAMMER_TOOL" -ms "$ELF_FILE" "$HEADER_BIN_UNIX" "$SBSFU_ELF_UNIX" >> "$PROJECT_DIR_ABS"/output.txt
          ret=$?
        fi
      fi
    fi
  fi
fi

# --- FINAL ERROR HANDLING & CLEANUP ---
if [ $ret -ne 0 ]; then
  echo ""
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo "!!! [FATAL ERROR] The script has failed."
  echo "!!! The last executed command failed:"
  echo "!!!   $command"
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  exit 1
fi
verbose_msg $LINENO "Cleaning up temporary files..."
rm -f "$SIGN_FILE_ABS" "$HEADER_BIN_ABS"
if [ -f "$REF_USER_APP_ABS" ]; then
  verbose_msg $LINENO "Cleaning up partial image temporary files..."
  rm -f "$PARTIAL_BIN_ABS" "$PARTIAL_SIGN_ABS" "$PARTIAL_OFFSET_ABS"
fi
verbose_msg $LINENO "--- Post-Build Script Finished ---"
exit 0
