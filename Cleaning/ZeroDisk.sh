#!/bin/sh

function zerodisk0 {
	diskutil zerodisk disk0
	diskutil zerodisk disk0
	diskutil zerodisk disk0
	diskutil zerodisk disk0
	diskutil zerodisk disk0
	diskutil zerodisk disk0
	diskutil zerodisk disk0

	diskutil partitiondisk disk0 GPT JHFS+ MacOS 100%
}

function zerodisk1 {
	diskutil zerodisk disk1
	diskutil zerodisk disk1
	diskutil zerodisk disk1
	diskutil zerodisk disk1
	diskutil zerodisk disk1
	diskutil zerodisk disk1
	diskutil zerodisk disk1

	diskutil partitiondisk disk1 GPT APFS MacOS 100%
}

if [ -d "/Volumes/Image Volume" ]; then
	zerodisk0
elif [ -d "/Volumes/Install macOS Catalina" ]; then
	zerodisk1
else
	echo "Unable to find proper Volume directories." 
fi
