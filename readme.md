# CC-OS README
This is the Read me for CC-OS a computer craft OS (tequicly not an OS) for reffrence the folder labled "root" is not the root of the project but is the root of the OS.
To install on a Computer craft computer simply insert the boot disk, *how you put the code on the disk uknown and not my ressponsibility*
Ulternately run ```pastebin run TvaxJizE```
As of yet **there is no uninstaller** just run:
```
rm root
rm installerLog.log
rm startup.lua
```
*Yes in the  time it took to write this I could have made one.*

## Running locally (CraftOS-PC)
```
.\run-local.ps1                               # boot the VM in .vm\ (remembers PCs + peripherals)
.\run-local.ps1 -Computers 2                  # two networked PCs
.\run-local.ps1 -Peripherals default,mekanism # pick which emulated devices to attach
.\run-local.ps1 -ListPeripherals              # list the peripheral lists in .vm\peripherals
```
Peripheral lists are text files in `.vm\peripherals\` (format explained in `default.txt`), or pass a path to your own.
Mod devices like Mekanism are faked in Lua by `dev\mock-peripherals.lua`.

Insert image of OS here

# AI:
AI was used in the creation of this project for example the enetirity of the dev tools vm section and the code was bug fixed an assisted in writing by AI along with an AI prototype but all code in the main project was at least overseen by a person if not mostly written by them. Also the docs above on the dev tools are AI.

# plan:
Use this (from AI prototype)
```
package.path = "/root/sys/?.lua;/root/sys/?/init.lua;"
    .. "/OSadditinalResources/Classes/?.lua;/OSadditinalResources/Classes/?/init.lua;"
    .. package.path
```