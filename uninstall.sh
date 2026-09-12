#
# Copyright (C) 2026 The WitAqua Project
# SPDX-License-Identifier: Apache-2.0
#

# The app was installed rather than overlaid, so removing the module has to
# remove it too - otherwise it is left behind with no way to explain itself.
pm uninstall org.witaqua.qcom.pd_info.root >/dev/null 2>&1
