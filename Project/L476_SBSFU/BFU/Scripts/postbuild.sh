#!/bin/bash -
echo "Extract SE interface symbols"
arm-none-eabi-nm $1 > ../Scripts/nm.txt
case "$(uname -s)" in
    Linux*|Darwin*)
      tr -d '\015' <../Scripts/se_interface.txt > ../Scripts/se_interface_unix.txt
      grep -F -f ../Scripts/se_interface_unix.txt nm.txt > ../Scripts/symbol.list
      rm ../Scripts/se_interface_unix.txt
      ;;
    *)
      grep -F -f ../Scripts//se_interface.txt ../Scripts/nm.txt > ../Scripts/symbol.list
      ;;
esac
wc -l ../Scripts/symbol.list
cat ../Scripts/symbol.list | awk '{split($0,a,/[ \r]/); print a[3]" = 0x"a[1]";"}' > "$2"/Linker/se_interface_app.ld
rm ../Scripts/nm.txt
rm ../Scripts/symbol.list
