#!/bin/bash -

# Pre build for script for the Secure Engine
#  $1 is the Project Directory
#  $2 is the Common Directory
#  $3 is for the Output Folder

if [ -z "$1" ]; then
  echo "Usage: $0 <Project Directory> <Common Directory> <Output Folder>"
  exit 1
fi

if [ -z "$2" ]; then
  echo "Usage: $0 <Project Directory> <Common Directory> <Output Folder>"
  exit 1
fi

if [ -z "$3" ]; then
  echo "Usage: $0 <Project Directory> <Common Directory> <Output Folder>"
  exit 1
fi

if [ ! -d "$1" ]; then
  echo Project Directory "$1" does not exist.
  exit 1
fi


if [ ! -d "$2" ]; then
  echo Common Directory "$2" does not exist.
  exit 1
fi

if [ ! -d "$2"/Binary ]; then
  echo Common Directory "$2"/Binary does not exist.
  exit 1
fi

if [ ! -d "$2"/Binary_Keys ]; then
  echo Common Directory "$2"/Binary_Keys does not exist.
  exit 1
fi

if [ ! -d "$2"/Debug ]; then
  echo Common Directory "$2"/Debug does not exist.
  exit 1
fi

if [ ! -d "$2"/Debug/Middlewares ]; then
  echo Common Directory "$2"/Debug/Middlewares does not exist.
  exit 1
fi

if [ ! -d "$2"/Debug/Middlewares/STM32_Secure_Engine ]; then
  echo Common Directory "$2"/Debug/Middlewares/STM32_Secure_Engine does not exist.
  exit 1
fi

if [ ! -d "$2"/KeysAndImages_Util ]; then
  echo Common Directory "$2"/KeysAndImages_Util does not exist.
  exit 1
fi

if [ ! -d "$2"/Linker ]; then
  echo Common Directory "$2"/Linker does not exist.
  exit 1
fi

if [ ! -d "$2"/Scripts ]; then
  echo Common Directory "$2"/Scripts does not exist.
  exit 1
fi

if [ ! -d "$2"/Startup ]; then
  echo Common Directory "$2"/Startup does not exist.
  exit 1
fi

if [ ! -d "$3" ]; then
  mkdir -p "$3"
  if [ $? -ne 0 ]; then
    echo "Failed to create Output directory $3"
    exit 1
  fi
fi


current_dir=`pwd`

cd "$1"
project_dir=`pwd`

cd "$current_dir"
cd "$2"
common_dir=`pwd`



cd "$current_dir"
cd "$3"
output_dir=`pwd`


cd "$project_dir"/Scripts
scripts_dir=`pwd`


cd "$common_dir"/Binary_Keys
common_binary_keys_dir=`pwd`


cd "$common_dir"/KeysAndImages_Util
common_image_dir=`pwd`


cd "$common_dir"/Scripts
common_scripts_dir=`pwd`


cd "$common_dir"/Startup
common_startup_dir=`pwd`


cd "$current_dir"


echo prebuild.sh : started > "$output_dir"/output.txt
asmfile="$common_startup_dir"/se_key.s

# python is used if  executable not found

# test if window executable usable
prepareimage="$common_image_dir"/win/prepareimage/prepareimage.exe
uname  | grep -i -e windows -e mingw > /dev/null 2>&1


if [ $? -eq 0 ] && [  -e "$prepareimage" ]; then
  echo "prepareimage with windows executable" >> "$output_dir"/output.txt
  echo "prepareimage with windows executable"
  cmd=""
else
  # line for python
  echo "prepareimage with python script" >> "$output_dir"/output.txt
  echo "prepareimage with python script"
  prepareimage="$common_image_dir"/prepareimage.py
  unameOut="$(uname -s)"
  case "${unameOut}" in
    Linux*)     machine=Linux;;
    Darwin*)    machine=Mac;;
    CYGWIN*)    machine=windows;;
    MINGW*)     machine=windows;;
    Windows_NT*)  machine=windows;;
    *)          machine="UNKNOWN:${unameOut}"
    esac
  if [ ${machine} == windows ];then
    cmd=python
  else
    cmd=python3
  fi
fi

echo "$cmd $prepareimage" >> "$output_dir"/output.txt
crypto_h="$project_dir"/Application/Core/Inc/se_crypto_config.h

#clean
if [ -e "$output_dir"/crypto.txt ]; then
  rm "$output_dir"/crypto.txt
fi

if [ -e "$asmfile" ]; then
  rm "$asmfile"
fi

if [ -e "$common_scripts_dir"/postbuild.sh ]; then
  rm "$common_scripts_dir"/postbuild.sh
fi


#get crypto name
command="$cmd \"$prepareimage\" conf \"$crypto_h\""
echo "$command"
crypto=$(eval $command)
echo $crypto > "$output_dir"/crypto.txt
echo "$crypto selected">> "$output_dir"/output.txt
echo $crypto selected
ret=$?

cortex="V7M"
echo "	.section .SE_Key_Data,\"a\",%progbits" > "$asmfile"
echo "	.syntax unified" >> "$asmfile"
echo "	.thumb " >> "$asmfile"


# AES keys part
if [ $ret -eq 0 ]; then
  type="vide"
  if [ "$crypto" = "SECBOOT_AES128_GCM_AES128_GCM_AES128_GCM" ]; then
    type="GCM"
  fi
  if [ "$crypto" = "SECBOOT_ECCDSA_WITH_AES128_CBC_SHA256" ]; then
    type="CBC"
  fi

  if [ $type != "vide" ]; then
    oemkey="$common_binary_keys_dir"/OEM_KEY_COMPANY1_key_AES_$type.bin
    command="$cmd \"$prepareimage\" trans -a GNU -k $oemkey -f SE_ReadKey_1 -v $cortex"
    echo "$command"
    $cmd "$prepareimage" trans -a GNU -k "$oemkey" -f SE_ReadKey_1 -v $cortex >> "$asmfile"
    ret=$?

    if [ $ret -eq 0 ]; then
      oemkey="$common_binary_keys_dir"/OEM_KEY_COMPANY2_key_AES_$type.bin
      if [ -e "$oemkey" ]; then
        command="$cmd \"$prepareimage\" trans -a GNU -k $oemkey -f SE_ReadKey_2 -v $cortex"
        echo "$command"
        $cmd "$prepareimage" trans -a GNU -k $oemkey -f SE_ReadKey_2 -v $cortex >> "$asmfile"
        ret=$?
      fi
    fi

    if [ $ret -eq 0 ]; then
        oemkey="$common_binary_keys_dir"/OEM_KEY_COMPANY3_key_AES_$type.bin
        if [ -e "$oemkey" ]; then
            command="$cmd \"$prepareimage\" trans -a GNU -k $oemkey -f SE_ReadKey_3 -v $cortex"
            echo "$command"
            $cmd "$prepareimage" trans -a GNU -k $oemkey -f SE_ReadKey_3 -v $cortex >> "$asmfile"
            ret=$?
        fi
    fi
  fi
fi


# ECC keys part
if [ $ret -eq 0 ]; then
  type="vide"
  if [ "$crypto" = "SECBOOT_ECCDSA_WITHOUT_ENCRYPT_SHA256" ]; then
    type="ECC"
  fi
  if [ "$crypto" = "SECBOOT_ECCDSA_WITH_AES128_CBC_SHA256" ]; then
    type="ECC"
  fi

  if [ $type != "vide" ]; then
    ecckey="$common_binary_keys_dir"/ECCKEY1.txt
    command="$cmd \"$prepareimage\" trans  -a GNU -k \"$ecckey\" -f SE_ReadKey_1_Pub -v $cortex"
    echo "$command"
    $cmd "$prepareimage" trans  -a GNU -k "$ecckey" -f SE_ReadKey_1_Pub -v $cortex >> "$asmfile"
    ret=$?

    if [ $ret -eq 0 ]; then
      ecckey="$common_binary_keys_dir"/ECCKEY2.txt
      if [ -e "$ecckey" ]; then
        command="$cmd \"$prepareimage\" trans  -a GNU -k \"$ecckey\" -f SE_ReadKey_2_Pub -v $cortex"
        echo "$command"
        $cmd "$prepareimage" trans  -a GNU -k "$ecckey" -f SE_ReadKey_2_Pub -v $cortex >> "$asmfile"
        ret=$?
      fi
    fi

    if [ $ret -eq 0 ]; then
      ecckey="$common_binary_keys_dir"/ECCKEY3.txt
      if [ -e "$ecckey" ]; then
        command="$cmd \"$prepareimage\" trans  -a GNU -k \"$ecckey\" -f SE_ReadKey_3_Pub -v $cortex"
        echo "$command"
        $cmd "$prepareimage" trans  -a GNU -k "$ecckey" -f SE_ReadKey_3_Pub -v $cortex >> "$asmfile"
        ret=$?
      fi
    fi
  fi
fi
echo "    .end" >> "$asmfile"

if [ $ret -eq 0 ]; then
#no error recopy post build script
    uname  | grep -i -e windows -e mingw > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "recopy postbuild.sh script with "$crypto".sh script"
        command="cat \"$scripts_dir\"/\"$crypto.sh\""
        echo "$command"
        cat "$scripts_dir"/"$crypto.sh" > "$common_scripts_dir"/postbuild.sh
        ret=$?
    else
        echo "create symbolic link postbuild.sh to "$crypto".sh"
        command="ln -s \"$scripts_dir\"/\"$crypto.sh\" \"$common_scripts_dir\"/postbuild.sh"
        echo "$command"
        ln -s "$scripts_dir"/"$crypto.sh" "$common_scripts_dir"/postbuild.sh
        ret=$?
    fi
fi

if [ $ret != 0 ]; then
#an error
echo "$command" : failed >> "$output_dir"/output.txt
echo "$command" : failed
read -n 1 -s
exit 1
fi
exit 0
