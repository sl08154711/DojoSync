# DojoSync

Shell script to synchronise databases of [Kanji-Dojo](https://github.com/syt0r/Kanji-Dojo) across multiple devices.

## Prerequisites

In order to use the script please make sure you have (for each device):
- Termux installed
- root access
- compiled sqldiff
- an ssh account somewhere
- ssh client installed
- enough courage and or or backups

## How to use

Just copy the script to your device possibly using aforementioned ssh client and just run it. The script will create backups on the device and in the remote location and run Kanji-Dojo. After you close the app the script will synchronise your progress or if anything goes wrong with your internet connection it might trash all databases. Good luck!
You could use Termux:Widget to create a shortcut and make it a bit nicer.
Don't think for one moment this thing works as intended. Only use it if you're really know what you're doing.

