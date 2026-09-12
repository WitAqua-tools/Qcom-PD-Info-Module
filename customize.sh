#
# Copyright (C) 2026 The WitAqua Project
# SPDX-License-Identifier: Apache-2.0
#

ui_print "- Qualcomm PD Info"

# The app is installed rather than overlaid into /system: it is an ordinary
# application, signed with our own key, and has no business on the system
# image. A module that only carried an apk would install and do nothing.
APK=$MODPATH/QcomPdInfoRoot.apk
if [ ! -f "$APK" ]; then
  abort "! QcomPdInfoRoot.apk is missing from the module"
fi

ui_print "- Installing the viewer"
if pm install -r -i com.android.vending "$APK" >/dev/null 2>&1; then
  ui_print "  installed"
else
  # A signature clash with an existing install is the one failure worth
  # naming, because uninstalling first is the only way past it.
  ui_print "  ! could not install. If an older build is present and was signed"
  ui_print "    with a different key, uninstall it and flash this again."
fi

# Say up front whether the interface this needs is even there, because on a
# board without it the app has nothing to report and that is not the install's
# fault.
if [ -d /sys/class/usbpd ]; then
  ui_print "- Qualcomm's own power delivery driver is present; the object list"
  ui_print "  comes from there and needs none of the debugfs path."
elif [ -d /sys/class/usb_power_delivery ]; then
  ui_print "- The upstream power delivery class is present."
  if [ -n "$(ls /sys/class/usb_power_delivery/*/source-capabilities 2>/dev/null)" ]; then
    ui_print "  It carries the object lists already."
  else
    ui_print "  It carries no object lists, so the viewer will ask the policy"
    ui_print "  manager over debugfs. That is what post-fs-data.sh mounts."
  fi
else
  ui_print "! This kernel publishes no power delivery interface at all."
fi

ui_print "- Reboot, then open \"USB Power Delivery\" and grant it root."

set_perm_recursive "$MODPATH" 0 0 0755 0644
