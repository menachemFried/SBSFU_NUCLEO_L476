#!/bin/sh
# ==============================================================================
#
# POST-BUILD SCRIPT for SECBOOT_AES128_GCM_WITH_AES128_GCM
#
# This script is designed to be run after the build process of the SBSFU project.
# It performs the following tasks:
# 1. Validates input arguments and assigns them to relative variables.
# 2. Converts all paths to absolute paths and logs them.
# 3. Validates the project structure.
# 4. Defines all file variables with absolute paths and logs them.
# 5. Selects the appropriate prepareimage tool based on the platform.
# 6. Executes the main flow of the script, which includes:
#    - Encrypting the binary file.
#    - Signing the binary file.
#    - Packing the SFB file.
#    - Creating the header binary file.
#    - Merging to create the big binary file.
#    - Optionally generating a partial image if a reference user app exists.
# 7. Handles errors and provides verbose output for debugging.
#
# arg1 is the build directory
# arg2 is the elf file path+name
# arg3 is the bin file path+name
# arg4 is the firmware Id (1/2/3)
# arg5 is the version
# arg6 when present forces "bigelf" generation
#
# ==============================================================================

# --- 1. SCRIPT CONFIGURATION ---
DEBUG_MODE=0            # Set to 1 to enable debug messages, 0 to disable
VERBOSE_MODE=1          # Set to 1 to enable verbose messages, 0 to disable


# --- 2. HELPER FUNCTION ---
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
verbose_msg $LINENO "--- Post-Build Script Started ---"

# --- STEP A: VALIDATION AND INITIAL VARIABLE ASSIGNMENT ---
verbose_msg $LINENO "Validating arguments and assigning initial relative variables..."

if [ "$#" -lt 5 ]; then
  echo "ERROR: At least 5 arguments are required."
  echo "Usage: $0 <build_dir> <elf_file> <bin_file> <fw_id> <version> [force_bigelf]"
  exit 1
fi

# Store and log relative arguments
PROJECT_DIR_REL="$1"
log_msg $LINENO "Relative Arg 1 (Project Dir): \"$PROJECT_DIR_REL\""
ELF_FILE="$2"
log_msg $LINENO "Relative Arg 2 (ELF File): \"$ELF_FILE\""
BIN_FILE_REL="$3"
log_msg $LINENO "Relative Arg 3 (BIN File): \"$BIN_FILE_REL\""
FW_ID="$4"
log_msg $LINENO "Relative Arg 4 (FW ID): \"$FW_ID\""
VERSION="$5"
log_msg $LINENO "Relative Arg 5 (Version): \"$VERSION\""

if [ "$#" -eq 6 ]; then
  FORCE_BIGELF=1
  log_msg $LINENO "Relative Arg 6 detected: 'force_bigelf' is enabled."
else
  FORCE_BIGELF=0
fi

# --- STEP B: CONVERT ALL PATHS TO ABSOLUTE AND LOG THEM ---
log_msg $LINENO "Converting all paths to absolute and logging them..."

COMMON_ABS_DIR=$(cd "$(dirname "$(dirname "$0")")" && pwd)
log_msg $LINENO "Common Directory (Absolute): \"$COMMON_ABS_DIR\""

PROJECT_DIR_ABS=$(cd "$PROJECT_DIR_REL" && pwd)
log_msg $LINENO "Project Build Directory (Absolute): \"$PROJECT_DIR_ABS\""


BIN_NAME="${3##*/}"
log_msg $LINENO "bin file name: \"$BIN_NAME\""


BIN_DIR_REL="$(dirname "$3")"
log_msg $LINENO "bin file Directory (Reletive): \"$BIN_DIR_REL\""



BIN_FILE_ABS=$(cd "$BIN_DIR_REL" && pwd)/"$BIN_NAME"
log_msg $LINENO "BIN File (Absolute): \"$BIN_FILE_ABS\""



BINARY_OUTPUT_DIR_ABS=$(cd "$PROJECT_DIR_ABS/../Binary" && pwd)
log_msg $LINENO "Binary Output Directory (Absolute): \"$BINARY_OUTPUT_DIR_ABS\""

KEYS_AND_IMAGES_DIR_ABS=$(cd "$COMMON_ABS_DIR/KeysAndImages_Util" && pwd)
log_msg $LINENO "Keys/Images Util Directory (Absolute): \"$KEYS_AND_IMAGES_DIR_ABS\""

SBSFU_ELF_ABS=$(cd "$COMMON_ABS_DIR/Debug" && pwd)/SBSFU.elf
log_msg $LINENO "SBSFU ELF (Absolute): \"$SBSFU_ELF_ABS\""

REF_USER_APP_ABS="$PROJECT_DIR_ABS/RefUserApp.bin"
log_msg $LINENO "Reference User App (Absolute): \"$REF_USER_APP_ABS\""


# --- STEP C: PROJECT STRUCTURE VALIDATION ---
verbose_msg $LINENO "Validating project structure using absolute paths..."
if [ ! -d "$KEYS_AND_IMAGES_DIR_ABS" ]; then
  verbose_msg $LINENO "ERROR: Required directory for 'prepareimage' tool does not exist at "$KEYS_AND_IMAGES_DIR_ABS"."
  exit 1
fi


if [ ! -d "$COMMON_ABS_DIR"/Binary ]; then
  verbose_msg $LINENO Common Directory "$COMMON_ABS_DIR"/Binary does not exist.
  exit 1
fi

if [ ! -d "$COMMON_ABS_DIR"/Binary_Keys ]; then
  verbose_msg $LINENO Common Directory "$COMMON_ABS_DIR"/Binary_Keys does not exist.
  exit 1
fi

if [ ! -d "$COMMON_ABS_DIR"/Debug ]; then
  verbose_msg $LINENO Common Directory "$COMMON_ABS_DIR"/Debug does not exist.
  exit 1
fi

if [ ! -d "$COMMON_ABS_DIR"/Debug/Middlewares ]; then
  verbose_msg $LINENO Common Directory "$COMMON_ABS_DIR"/Debug/Middlewares does not exist.
  exit 1
fi

if [ ! -d "$COMMON_ABS_DIR"/Debug/Middlewares/STM32_Secure_Engine ]; then
  verbose_msg $LINENO Common Directory "$COMMON_ABS_DIR"/Debug/Middlewares/STM32_Secure_Engine does not exist.
  exit 1
fi

if [ ! -d "$COMMON_ABS_DIR"/KeysAndImages_Util ]; then
  verbose_msg $LINENO Common Directory "$COMMON_ABS_DIR"/KeysAndImages_Util does not exist.
  exit 1
fi

if [ ! -d "$COMMON_ABS_DIR"/Linker ]; then
  verbose_msg $LINENO Common Directory "$COMMON_ABS_DIR"/Linker does not exist.
  exit 1
fi

if [ ! -d "$COMMON_ABS_DIR"/Scripts ]; then
  verbose_msg $LINENO Common Directory "$COMMON_ABS_DIR"/Scripts does not exist.
  exit 1
fi

if [ ! -d "$COMMON_ABS_DIR"/Startup ]; then
  verbose_msg $LINENO Common Directory "$COMMON_ABS_DIR"/Startup does not exist.
  exit 1
fi

verbose_msg $LINENO "Project structure validation successful."

# --- STEP D: DEFINE FILE VARIABLES AND LOG THEM ---
verbose_msg $LINENO "Defining all file variables with absolute paths and logging them..."

EXEC_NAME=$(basename "$BIN_FILE_ABS" .bin)
log_msg $LINENO "Executable Name: \"$EXEC_NAME\""
SFU_FILE_ABS="${BINARY_OUTPUT_DIR_ABS}/${EXEC_NAME}.sfu"
log_msg $LINENO "SFU File (Absolute): \"$SFU_FILE_ABS\""
SFB_FILE_ABS="${BINARY_OUTPUT_DIR_ABS}/${EXEC_NAME}.sfb"
log_msg $LINENO "SFB File (Absolute): \"$SFB_FILE_ABS\""
SIGN_FILE_ABS="${BINARY_OUTPUT_DIR_ABS}/${EXEC_NAME}.sign"
log_msg $LINENO "SIGN File (Absolute): \"$SIGN_FILE_ABS\""
HEADER_BIN_ABS="${BINARY_OUTPUT_DIR_ABS}/${EXEC_NAME}sfuh.bin"
log_msg $LINENO "Header BIN File (Absolute): \"$HEADER_BIN_ABS\""
BIGBINARY_ABS="${BINARY_OUTPUT_DIR_ABS}/SBSFU_${EXEC_NAME}.bin"
log_msg $LINENO "Big Binary File (Absolute): \"$BIGBINARY_ABS\""
NONCE_FILE_ABS="${COMMON_ABS_DIR}/Binary_Keys/nonce.bin"
log_msg $LINENO "Nonce File (Absolute): \"$NONCE_FILE_ABS\""
OEM_KEY_ABS="${COMMON_ABS_DIR}/Binary_Keys/OEM_KEY_COMPANY${FW_ID}_key_AES_GCM.bin"
log_msg $LINENO "OEM Key File (Absolute): \"$OEM_KEY_ABS\""
MAGIC="SFU${FW_ID}"
log_msg $LINENO "Magic: \"$MAGIC\""

OFFSET=512
log_msg $LINENO "Offset: \"$OFFSET\""
ALIGNMENT=16
log_msg $LINENO "Alignment: \"$ALIGNMENT\""


PARTIAL_BIN_ABS="${BINARY_OUTPUT_DIR_ABS}/Partial${EXEC_NAME}.bin"
log_msg $LINENO "Partial BIN File (Absolute): \"$PARTIAL_BIN_ABS\""
PARTIAL_SFU_ABS="${BINARY_OUTPUT_DIR_ABS}/Partial${EXEC_NAME}.sfu"
log_msg $LINENO "Partial SFU File (Absolute): \"$PARTIAL_SFU_ABS\""
PARTIAL_SIGN_ABS="${BINARY_OUTPUT_DIR_ABS}/Partial${EXEC_NAME}.sign"
log_msg $LINENO "Partial SIGN File (Absolute): \"$PARTIAL_SIGN_ABS\""
PARTIAL_SFB_ABS="${BINARY_OUTPUT_DIR_ABS}/Partial${EXEC_NAME}.sfb"
log_msg $LINENO "Partial SFB File (Absolute): \"$PARTIAL_SFB_ABS\""
PARTIAL_OFFSET_ABS="${BINARY_OUTPUT_DIR_ABS}/Partial${EXEC_NAME}.offset"
log_msg $LINENO "Partial Offset File (Absolute): \"$PARTIAL_OFFSET_ABS\""


# --- STEP E: SELECT PREPAREIMAGE TOOL ---
verbose_msg $LINENO "Detecting platform to select prepareimage tool..."
PREPARE_IMAGE_CMD="python"
PREPARE_IMAGE_SCRIPT="\"${KEYS_AND_IMAGES_DIR_ABS}/prepareimage.py\""


# test if window executable usable


if uname | grep -i -e windows -e mingw >/dev/null 2>&1 && [ -f "${KEYS_AND_IMAGES_DIR_ABS}/win/prepareimage/prepareimage.exe" ]; then
    verbose_msg $LINENO "Windows environment detected. Using prepareimage.exe"
    PREPARE_IMAGE_CMD="${KEYS_AND_IMAGES_DIR_ABS}/win/prepareimage/prepareimage.exe"
    PREPARE_IMAGE_SCRIPT=""
else
    verbose_msg $LINENO "Linux/macOS or no .exe found. Using python script."
fi
log_msg $LINENO "Prepareimage command set to: $PREPARE_IMAGE_CMD"
log_msg $LINENO "Prepareimage script set to: $PREPARE_IMAGE_SCRIPT"

# --- STEP F: MAIN EXECUTION FLOW (with nested ifs) ---
log_msg $LINENO "Ensuring Binary output directory exists..."
mkdir -p "$BINARY_OUTPUT_DIR_ABS"
ret=$?
if [ $ret -eq 0 ]; then
  # Convert paths to Unix format for the tool
  verbose_msg $LINENO "Converting paths to UNIX format for the tool..."
  BIN_FILE_UNIX=$(echo "$BIN_FILE_ABS" | sed 's/\\/\//g')
  log_msg $LINENO "UNIX-formatted BIN File: \"$BIN_FILE_UNIX\""
  SFU_FILE_UNIX=$(echo "$SFU_FILE_ABS" | sed 's/\\/\//g')
  log_msg $LINENO "UNIX-formatted SFU File: \"$SFU_FILE_UNIX\""
  SIGN_FILE_UNIX=$(echo "$SIGN_FILE_ABS" | sed 's/\\/\//g')
  log_msg $LINENO "UNIX-formatted SIGN File: \"$SIGN_FILE_UNIX\""
  SFB_FILE_UNIX=$(echo "$SFB_FILE_ABS" | sed 's/\\/\//g')
  log_msg $LINENO "UNIX-formatted SFB File: \"$SFB_FILE_UNIX\""
  HEADER_BIN_UNIX=$(echo "$HEADER_BIN_ABS" | sed 's/\\/\//g')
  log_msg $LINENO "UNIX-formatted Header BIN File: \"$HEADER_BIN_UNIX\""
  BIGBINARY_UNIX=$(echo "$BIGBINARY_ABS" | sed 's/\\/\//g')
  log_msg $LINENO "UNIX-formatted Big Binary File: \"$BIGBINARY_UNIX\""
  OEM_KEY_UNIX=$(echo "$OEM_KEY_ABS" | sed 's/\\/\//g')
  log_msg $LINENO "UNIX-formatted OEM Key File: \"$OEM_KEY_UNIX\""
  NONCE_UNIX=$(echo "$NONCE_FILE_ABS" | sed 's/\\/\//g')
  log_msg $LINENO "UNIX-formatted Nonce File: \"$NONCE_UNIX\""
  SBSFU_ELF_UNIX=$(echo "$SBSFU_ELF_ABS" | sed 's/\\/\//g')
  log_msg $LINENO "UNIX-formatted SBSFU ELF File: \"$SBSFU_ELF_UNIX\""

  verbose_msg $LINENO "1. Encrypting binary..."
  command="\"$PREPARE_IMAGE_CMD\"\"$PREPARE_IMAGE_SCRIPT\" enc -k \"$OEM_KEY_UNIX\" -n \"$NONCE_UNIX\" \"$BIN_FILE_UNIX\" \"$SFU_FILE_UNIX\""
  log_msg $LINENO "EXECUTING: $command"
  "$PREPARE_IMAGE_CMD""$PREPARE_IMAGE_SCRIPT" enc -k "$OEM_KEY_UNIX" -n "$NONCE_UNIX" "$BIN_FILE_UNIX" "$SFU_FILE_UNIX" > "$PROJECT_DIR_ABS"/output.txt
  ret=$?
if [ $ret -eq 0 ]; then
  verbose_msg $LINENO "2. Signing binary..."
  command="\"$PREPARE_IMAGE_CMD\"\"$PREPARE_IMAGE_SCRIPT\" sign -k \"$OEM_KEY_UNIX\" -n \"$NONCE_UNIX\" \"$BIN_FILE_UNIX\" \"$SIGN_FILE_UNIX\""
  log_msg $LINENO "EXECUTING: $command"
  "$PREPARE_IMAGE_CMD""$PREPARE_IMAGE_SCRIPT" sign -k "$OEM_KEY_UNIX" -n "$NONCE_UNIX" "$BIN_FILE_UNIX" "$SIGN_FILE_UNIX" > "$PROJECT_DIR_ABS"/output.txt
  ret=$?
    if [ $ret -eq 0 ]; then
      verbose_msg $LINENO "3. Packing SFB file..."
      command="\"$PREPARE_IMAGE_CMD\"\"$PREPARE_IMAGE_SCRIPT\" pack -m \"$MAGIC\" -k \"$OEM_KEY_UNIX\" -r 112 -v \"$VERSION\" -n \"$NONCE_UNIX\" -f \"$SFU_FILE_UNIX\" -t \"$SIGN_FILE_UNIX\" \"$SFB_FILE_UNIX\" -o \"$OFFSET\""
      log_msg $LINENO "EXECUTING: $command"
      "$PREPARE_IMAGE_CMD""$PREPARE_IMAGE_SCRIPT" pack -m "$MAGIC" -k "$OEM_KEY_UNIX" -r 112 -v "$VERSION" -n "$NONCE_UNIX" -f "$SFU_FILE_UNIX" -t "$SIGN_FILE_UNIX" "$SFB_FILE_UNIX" -o "$OFFSET" >> "$PROJECT_DIR_ABS"/output.txt
      ret=$?
      if [ $ret -eq 0 ]; then
        verbose_msg $LINENO "4. Creating header binary..."
        command="\"$PREPARE_IMAGE_CMD\"\"$PREPARE_IMAGE_SCRIPT\" header -m \"$MAGIC\" -k \"$OEM_KEY_UNIX\" -r 112 -v \"$VERSION\" -n \"$NONCE_UNIX\" -f \"$SFU_FILE_UNIX\" -t \"$SIGN_FILE_UNIX\" -o \"$OFFSET\" \"$HEADER_BIN_UNIX\""
        log_msg $LINENO "EXECUTING: $command"
        "$PREPARE_IMAGE_CMD""$PREPARE_IMAGE_SCRIPT" header -m "$MAGIC" -k "$OEM_KEY_UNIX" -r 112 -v "$VERSION" -n "$NONCE_UNIX" -f "$SFU_FILE_UNIX" -t "$SIGN_FILE_UNIX" -o "$OFFSET" "$HEADER_BIN_UNIX" >> "$PROJECT_DIR_ABS"/output.txt
        ret=$?
        if [ $ret -eq 0 ]; then
          verbose_msg $LINENO "5. Merging to create big binary..."
          command="\"$PREPARE_IMAGE_CMD\"\"$PREPARE_IMAGE_SCRIPT\" merge -v 0 -e 1 -i \"$HEADER_BIN_UNIX\" -s \"$SBSFU_ELF_UNIX\" -u \"$ELF_FILE\" \"$BIGBINARY_UNIX\""
          log_msg $LINENO "EXECUTING: $command"
          "$PREPARE_IMAGE_CMD""$PREPARE_IMAGE_SCRIPT" merge -v 0 -e 1 -i "$HEADER_BIN_UNIX" -s "$SBSFU_ELF_UNIX" -u "$ELF_FILE" "$BIGBINARY_UNIX" >> "$PROJECT_DIR_ABS"/output.txt
          ret=$?
          if [ $ret -eq 0 ]; then
            # Partial image generation if reference userapp exists
            verbose_msg $LINENO "Checking for partial image generation..."
            if [ -f "$REF_USER_APP_ABS" ]; then
              verbose_msg $LINENO "Reference user app found. Starting partial image generation."

              PARTIAL_BIN_UNIX=$(echo "$PARTIAL_BIN_ABS" | sed 's/\\/\//g')
              log_msg $LINENO "UNIX-formatted Partial BIN File: \"$PARTIAL_BIN_UNIX\""
              PARTIAL_OFFSET_UNIX=$(echo "$PARTIAL_OFFSET_ABS" | sed 's/\\/\//g')
              log_msg $LINENO "UNIX-formatted Partial Offset File: \"$PARTIAL_OFFSET_UNIX\""
              PARTIAL_SFU_UNIX=$(echo "$PARTIAL_SFU_ABS" | sed 's/\\/\//g')
              log_msg $LINENO "UNIX-formatted Partial SFU File: \"$PARTIAL_SFU_UNIX\""
              PARTIAL_SIGN_UNIX=$(echo "$PARTIAL_SIGN_ABS" | sed 's/\\/\//g')
              log_msg $LINENO "UNIX-formatted Partial SIGN File: \"$PARTIAL_SIGN_UNIX\""
              PARTIAL_SFB_UNIX=$(echo "$PARTIAL_SFB_ABS" | sed 's/\\/\//g')
              log_msg $LINENO "UNIX-formatted Partial SFB File: \"$PARTIAL_SFB_UNIX\""
              REF_USER_APP_UNIX=$(echo "$REF_USER_APP_ABS" | sed 's/\\/\//g')
              log_msg $LINENO "UNIX-formatted Reference User App File: \"$REF_USER_APP_UNIX\""

              verbose_msg $LINENO "6a. Creating diff..."
              command="\"$PREPARE_IMAGE_CMD\"\"$PREPARE_IMAGE_SCRIPT\" diff -1 \"$REF_USER_APP_UNIX\" -2 \"$BIN_FILE_UNIX\" \"$PARTIAL_BIN_UNIX\" -a \"$ALIGNMENT\" --poffset \"$PARTIAL_OFFSET_UNIX\""
              log_msg $LINENO "EXECUTING: $command"
              "$PREPARE_IMAGE_CMD""$PREPARE_IMAGE_SCRIPT" diff -1 "$REF_USER_APP_UNIX" -2 "$BIN_FILE_UNIX" "$PARTIAL_BIN_UNIX" -a "$ALIGNMENT" --poffset "$PARTIAL_OFFSET_UNIX" >> "$PROJECT_DIR_ABS"/output.txt
              ret=$?
              if [ $ret -eq 0 ]; then
                verbose_msg $LINENO "6b. Encrypting partial binary..."
                command="\"$PREPARE_IMAGE_CMD\"\"$PREPARE_IMAGE_SCRIPT\" enc -k \"$OEM_KEY_UNIX\" -n \"$NONCE_UNIX\" \"$PARTIAL_BIN_UNIX\" \"$PARTIAL_SFU_UNIX\""
                log_msg $LINENO "EXECUTING: $command"
                "$PREPARE_IMAGE_CMD""$PREPARE_IMAGE_SCRIPT" enc -k "$OEM_KEY_UNIX" -n "$NONCE_UNIX" "$PARTIAL_BIN_UNIX" "$PARTIAL_SFU_UNIX" >> "$PROJECT_DIR_ABS"/output.txt
                ret=$?
                if [ $ret -eq 0 ]; then
                  verbose_msg $LINENO "6c. Signing partial binary..."
                  command="\"$PREPARE_IMAGE_CMD\"\"$PREPARE_IMAGE_SCRIPT\" sign -k \"$OEM_KEY_UNIX\" -n \"$NONCE_UNIX\" \"$PARTIAL_BIN_UNIX\" \"$PARTIAL_SIGN_UNIX\""
                  log_msg $LINENO "EXECUTING: $command"
                  "$PREPARE_IMAGE_CMD""$PREPARE_IMAGE_SCRIPT" sign -k "$OEM_KEY_UNIX" -n "$NONCE_UNIX" "$PARTIAL_BIN_UNIX" "$PARTIAL_SIGN_UNIX" >> "$PROJECT_DIR_ABS"/output.txt
                  ret=$?
                  if [ $ret -eq 0 ]; then
                    verbose_msg $LINENO "6d. Packing partial SFB..."
                    command="\"$PREPARE_IMAGE_CMD\"\"$PREPARE_IMAGE_SCRIPT\" pack -m \"$MAGIC\" -k \"$OEM_KEY_UNIX\" -r 112 -v \"$VERSION\" -n \"$NONCE_UNIX\" -f \"$SFU_FILE_UNIX\" -t \"$SIGN_FILE_UNIX\" -o 512 --pfw \"$PARTIAL_SFU_UNIX\" --ptag \"$PARTIAL_SIGN_UNIX\" --poffset \"$PARTIAL_OFFSET_UNIX\" \"$PARTIAL_SFB_UNIX\""
                    log_msg $LINENO "EXECUTING: $command"
                    "$PREPARE_IMAGE_CMD""$PREPARE_IMAGE_SCRIPT" pack -m "$MAGIC" -k "$OEM_KEY_UNIX" -r 112 -v "$VERSION" -n "$NONCE_UNIX" -f "$SFU_FILE_UNIX" -t "$SIGN_FILE_UNIX" -o 512 --pfw "$PARTIAL_SFU_UNIX" --ptag "$PARTIAL_SIGN_UNIX" --poffset "$PARTIAL_OFFSET_UNIX" "$PARTIAL_SFB_UNIX" >> "$PROJECT_DIR_ABS"/output.txt
                    ret=$?
                  fi
                fi
              fi
            fi
          else
            verbose_msg $LINENO "No reference user app found. Skipping partial image generation."
          fi
        fi
        # Merged ELF generation
        if [ $ret -eq 0 ] && [ "$FORCE_BIGELF" -eq 1 ]; then
          verbose_msg $LINENO "Force big ELF flag is set. Starting merged ELF generation."
          PROGRAMMER_TOOL="STM32_Programmer_CLI"
          if uname | grep -i -e windows -e mingw >/dev/null 2>&1; then
            if [ -f "C:/Program Files (x86)/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32_Programmer_CLI.exe" ]; then
                PROGRAMMER_TOOL="C:/Program Files (x86)/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32_Programmer_CLI.exe"
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

# --- FINAL ERROR HANDLING ---
if [ $ret -ne 0 ]; then
  echo ""
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo "!!! [FATAL ERROR] The script has failed."
  echo "!!! The last executed command failed:"
  echo "!!!   $command"
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  exit 1
fi

# --- CLEANUP (if successful) ---
verbose_msg $LINENO "Cleaning up temporary files..."
rm -f "$SIGN_FILE_ABS"
rm -f "$SFU_FILE_ABS"
rm -f "$HEADER_BIN_ABS"

if [ -f "$REF_USER_APP_ABS" ]; then
  verbose_msg $LINENO "Cleaning up partial image temporary files..."
  rm -f "$PARTIAL_BIN_ABS"
  rm -f "$PARTIAL_SFU_ABS"
  rm -f "$PARTIAL_SIGN_ABS"
  rm -f "$PARTIAL_OFFSET_ABS"
fi

verbose_msg $LINENO "--- Post-Build Script Finished Successfully ---"
exit 0
