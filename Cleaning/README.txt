=========================================================================================================================================================================

CleanDrive.bat is to clean several drives in quick succession, meant mostly for usage with USB drives.

clean.bat is meant as a WinRE compatible drive wipe. It uses diskpart's "clean all" seven times on whatever disk0 is, as long as it's not a classified as a USB.

ZeroDisk.sh is meant to be used in MacOS Recovery, when utilizing Terminal. Does a 7-pass of disktuil's zerodisk for disk0 if /Volumes/Image Volume/ exists, or disk1 if /Volumes/Install macOS Catalina/ exists when booted to Recovery.

=========================================================================================================================================================================
