#!/bin/bash -
#Post build for SECBOOT_AES128_GCM_WITH_AES128_GCM
# arg1 is the build directory
# arg2 is the elf file path+name
# arg3 is the bin file path+name
# arg4 is the firmware Id (1/2/3)
# arg5 is the version
# arg6 when present forces "bigelf" generation

current_dir=`pwd`

cd "$1"
projectdir=`pwd`
echo projectdir is "$projectdir"
cd "$current_dir"

FileName=${3##*/}
echo FileName is "$FileName"

execname=${FileName%.*}
echo execname is "$execname"

elf=$2
echo elf is "$elf"

bin_dir_link="$(dirname "$3")"
echo bin_dir_link is "$bin_dir_link"

cd "$bin_dir_link"
bin_dir=`pwd`
echo bin_dir is "$bin_dir"
cd "$current_dir"

bin="$bin_dir"/$FileName
echo bin is "$bin"



fwid=$4
echo fwid is "$fwid"

version=$5
echo version is "$version"

Common_dir_link=$(dirname "$(dirname "$0")")
echo Common_dir_link is "$Common_dir_link"

cd "$current_dir"/"$Common_dir_link"
Common_dir=`pwd`
echo Common_dir is "$Common_dir"
cd "$current_dir"


cd "$projectdir"/../Binary
userAppBinary=`pwd`
echo userAppBinary is "$userAppBinary"
cd "$current_dir"

sfu="$userAppBinary"/"$execname".sfu
echo sfu is "$sfu"

sfb="$userAppBinary"/"$execname".sfb
echo sfb is "$sfb"

sign="$userAppBinary"/"$execname".sign
echo sign is "$sign"

headerbin="$userAppBinary"/"$execname"sfuh.bin
echo headerbin is "$headerbin"

bigbinary="$userAppBinary"/SBSFU_"$execname".bin
echo bigbinary is "$bigbinary"

elfbackup="$userAppBinary"/SBSFU_"$execname".elf
echo elfbackup is "$elfbackup"

nonce="$Common_dir"/Binary_Keys/nonce.bin
echo nonce is "$nonce"

magic=SFU"$fwid"
echo magic is "$magic"

oemkey="$Common_dir"/Binary_Keys/OEM_KEY_COMPANY"$fwid"_key_AES_GCM.bin
echo oemkey is "$oemkey"

partialbin="$userAppBinary"/Partial"$execname".bin
echo partialbin is "$partialbin"

partialsfb="$userAppBinary"/Partial"$execname".sfb
echo partialsfb is "$partialsfb"

partialsfu="$userAppBinary"/Partial"$execname".sfu
echo partialsfu is "$partialsfu"

partialsign="$userAppBinary"/Partial"$execname".sign
echo partialsign is "$partialsign"

partialoffset="$userAppBinary"/Partial"$execname".offset
echo partialoffset is "$partialoffset"

ref_userapp="$projectdir"/RefUserApp.bin
echo ref_userapp is "$ref_userapp"

offset=512
alignment=16

# current_directory=`pwd`
# cd "$SecureEngine/../../"
# SecureDir=`pwd`
# cd "$current_directory"
# sbsfuelf="$SecureDir/2_Images_SBSFU/STM32CubeIDE/Debug/SBSFU.elf"
# current_directory=`pwd`
# cd "$1/../../../../../../Middlewares/ST/STM32_Secure_Engine/Utilities/KeysAndImages"
# basedir=`pwd`
# cd "$current_directory"
# # test if window executable usable
# prepareimage=$basedir"/win/prepareimage/prepareimage.exe"
# uname | grep -i -e windows -e mingw >/dev/null > /dev/null 2>&1
# if [ $? -eq 0 ] && [  -e "$prepareimage" ]; then
#   echo "prepareimage with windows executable"
#   PATH=$basedir"\\win\\prepareimage":$PATH > /dev/null 2>&1
#   cmd=""
#   prepareimage="prepareimage.exe"
# else
#   # line for python
#   echo "prepareimage with python script"
#   prepareimage=$basedir/prepareimage.py
#   cmd="python"
# fi

# # Make sure we have a Binary sub-folder in UserApp folder
# if [ ! -e $userAppBinary ]; then
# mkdir $userAppBinary
# fi

# command=$cmd" "$prepareimage" enc -k "$oemkey" -n "$nonce" "$bin" "$sfu
# $command > $projectdir"/output.txt"
# ret=$?
# if [ $ret -eq 0 ]; then
#   command=$cmd" "$prepareimage" sign -k "$oemkey" -n "$nonce" "$bin" "$sign
#   $command >> $projectdir"/output.txt"
#   ret=$?
#   if [ $ret -eq 0 ]; then
#     command=$cmd" "$prepareimage" pack -m "$magic" -k "$oemkey"  -r 112 -v "$version" -n "$nonce" -f "$sfu" -t "$sign" "$sfb" -o "$offset
#     $command >> $projectdir"/output.txt"
#     ret=$?
#     if [ $ret -eq 0 ]; then
#       command=$cmd" "$prepareimage" header -m "$magic" -k  "$oemkey" -r 112 -v "$version"  -n "$nonce" -f "$sfu" -t "$sign" -o "$offset" "$headerbin
#       $command >> $projectdir"/output.txt"
#       ret=$?
#       if [ $ret -eq 0 ]; then
#         command=$cmd" "$prepareimage" merge -v 0 -e 1 -i "$headerbin" -s "$sbsfuelf" -u "$elf" "$bigbinary
#         $command >> $projectdir"/output.txt"
#         ret=$?
#         #Partial image generation if reference userapp exists
#         if [ $ret -eq 0 ] && [ -e "$ref_userapp" ]; then
#           echo "Generating the partial image .sfb"
#           echo "Generating the partial image .sfb" >> $projectdir"/output.txt"
#           command=$cmd" "$prepareimage" diff -1 "$ref_userapp" -2 "$bin" "$partialbin" -a "$alignment" --poffset "$partialoffset
#           $command >> $projectdir"/output.txt"
#           ret=$?
#           if [ $ret -eq 0 ]; then
#             command=$cmd" "$prepareimage" enc -k "$oemkey" -i "$nonce" "$partialbin" "$partialsfu
#             $command >> $projectdir"/output.txt"
#             ret=$?
#             if [ $ret -eq 0 ]; then
#               command=$cmd" "$prepareimage" sign -k "$oemkey" -n "$nonce" "$partialbin" "$partialsign
#               $command >> $projectdir"/output.txt"
#               ret=$?
#               if [ $ret -eq 0 ]; then
#                 command=$cmd" "$prepareimage" pack -m "$magic" -k "$oemkey" -r 112 -v "$version" -i "$nonce" -f "$sfu" -t "$sign" -o "$offset" --pfw "$partialsfu" --ptag "$partialsign" --poffset  "$partialoffset" "$partialsfb
#                 $command >> $projectdir"/output.txt"
#                 ret=$?
#               fi
#             fi
#           fi
#         fi
#         if [ $ret -eq 0 ] && [ $# = 6 ]; then
#           echo "Generating the global elf file SBSFU and userApp"
#           echo "Generating the global elf file SBSFU and userApp" >> $projectdir"/output.txt"
#           uname | grep -i -e windows -e mingw > /dev/null 2>&1
#           if [ $? -eq 0 ]; then
#             # Set to the default installation path of the Cube Programmer tool
#             # If you installed it in another location, please update PATH.
#             PATH="C:\\Program Files (x86)\\STMicroelectronics\\STM32Cube\\STM32CubeProgrammer\\bin":$PATH > /dev/null 2>&1
#             programmertool="STM32_Programmer_CLI.exe"
#           else
#             which STM32_Programmer_CLI > /dev/null
#             if [ $? = 0 ]; then
#               programmertool="STM32_Programmer_CLI"
#             else
#               echo "fix access path to STM32_Programmer_CLI"
#             fi
#           fi
#           command=$programmertool" -ms "$elf" "$headerbin" "$sbsfuelf
#           $command >> $projectdir"/output.txt"
#           ret=$?
#         fi
#       fi
#     fi
#   fi
# fi


# if [ $ret -eq 0 ]; then
#   rm $sign
#   rm $sfu
#   rm $headerbin
#   if [ -e "$ref_userapp" ]; then
#     rm $partialbin
#     rm $partialsfu
#     rm $partialsign
#     rm $partialoffset
#   fi
#   exit 0
# else
#   echo "$command : failed" >> $projectdir"/output.txt"
#   if [ -e  "$elf" ]; then
#     rm  $elf
#   fi
#   if [ -e "$elfbackup" ]; then
#     rm  $elfbackup
#   fi
#   echo $command : failed
#   read -n 1 -s
#   exit 1
# fi


exit 1