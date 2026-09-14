#
# Copyright (C) 2026 The WitAqua Project
# SPDX-License-Identifier: Apache-2.0
#

# The viewer reads the charger's object list by putting GET_PDOS to the UCSI
# policy manager over the driver's debugfs interface. That is the only way in
# on a platform whose firmware does not report UCSI_CAP_PDO_DETAILS: the driver
# believes the report and never asks, so the usb_power_delivery class is
# registered and left empty.
#
# debugfs is not mounted by default, and deliberately so - AOSP's own sepolicy
# says "too much leaky information in debugfs" and neverallows reading it on a
# user build. Mounting a filesystem is also not something the app should be
# doing, which is why it happens here instead of there.
#
# So it is only mounted where it actually buys something. A kernel that
# publishes the objects properly needs none of this, and neither does one with
# qualcomm's own driver, which has them and the request object besides.

if [ -d /sys/class/usbpd ]; then
	# Qualcomm's own driver. It publishes the objects and the request.
	exit 0
fi

if [ ! -d /sys/class/usb_power_delivery ]; then
	# No power delivery interface at all; there is nothing to help with.
	exit 0
fi

for caps in /sys/class/usb_power_delivery/*/source-capabilities; do
	if [ -d "$caps" ]; then
		# The class carries the lists already.
		exit 0
	fi
done

if [ -d /sys/kernel/debug/usb/ucsi ]; then
	# Already reachable.
	exit 0
fi

# Leave an existing debugfs alone, and do not stack a second mount on it.
if grep -q ' /sys/kernel/debug debugfs ' /proc/mounts; then
	exit 0
fi

mount -t debugfs debugfs /sys/kernel/debug 2>/dev/null || exit 0

# A kernel without the UCSI debugfs interface - anything before android15-6.6 -
# gains nothing from the mount, and a class that registered no devices at all
# is that kernel. Leave no trace where there was nothing to reach.
if [ ! -d /sys/kernel/debug/usb/ucsi ]; then
	umount /sys/kernel/debug 2>/dev/null
fi
