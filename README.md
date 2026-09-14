# Qcom PD Info (module)

Installs the [USB Power Delivery
viewer](https://github.com/WitAqua/packages_apps_QcomPdInfo) and, where it is
the only way to get the charger's object list, mounts debugfs for it.

Read-only throughout: the app reports a negotiation, and only ever sends the
UCSI `GET_` commands.

## What it is for

The upstream `usb_power_delivery` class only carries the object lists when the
driver read them, and with UCSI that needs the firmware to report
`UCSI_CAP_PDO_DETAILS`. At least one platform - SM8850 with `pmic-glink`,
checked on a handset - answers `GET_PDOS` perfectly well while reporting a
features field of zero, so the driver never asks and the class is registered
and left empty.

The driver's own debugfs interface does not consult that bit, so the question
can still be put. debugfs is not mounted by default, and deliberately so, which
is what this module is for.

None of this applies to a board with Qualcomm's own power delivery driver, or
to one whose class carries the lists already. The module checks, and mounts
nothing where nothing is needed.

## Installing

Flash the zip in the KernelSU or Magisk manager and reboot. Then open **USB
Power Delivery** and grant it root.

Nothing here is specific to either: the installer uses only `ui_print`, `abort`
and `set_perm_recursive`, which both document with the same signatures, and
`post-fs-data.sh` and `updateJson` are the same in both. Built and tested
against KernelSU; it should work under Magisk, though that has not been run.

On KernelSU the app needs, in its App Profile:

| | |
| --- | --- |
| uid / gid | `0` / `0` |
| groups | `ROOT` |
| SELinux context | `u:r:ksu:s0` |

The context is the part that matters. The shell's own context cannot reach
either debugfs or the type-C class, whatever the uid. Magisk's own `su` runs in
a context that can, so there is nothing to configure there.

## What it does on install

`customize.sh` installs the apk and says which interface the board has, so it
is clear up front whether the object list will appear at all.

`post-fs-data.sh` mounts debugfs, and only where it buys something:

| Board | debugfs |
| --- | --- |
| Qualcomm's own driver (`/sys/class/usbpd`) | not mounted - it has the objects and the request |
| No power delivery interface | not mounted - nothing to help with |
| Upstream class carrying the lists | not mounted |
| Upstream class registered and empty | **mounted** |

Removing the module uninstalls the app, since the module is what installed it.

## Is leaving debugfs mounted a problem?

It is not nothing. AOSP's own policy says so:

```
# Too much leaky information in debugfs. It's a security
# best practice to ensure these files aren't readable.
neverallow all_untrusted_apps { debugfs_type -debugfs_kcov }:file read;
neverallow {all_untrusted_apps userdebug_or_eng(`-domain')} debugfs_type:{ file lnk_file } read;
```

The second line means no domain at all may read debugfs on a user build.

In practice the exposure is narrow: the mount point is `0700 root` and labelled
`debugfs`, so SELinux keeps every non-root domain out regardless. On a handset
that already has root, the meaningful cost is that the mount is persistent and
system-wide rather than that anything new can reach it.

Mounting it inside a private mount namespace instead would leave no trace at
all, and works - but it needs `CAP_SYS_ADMIN` in the app's profile, which
cannot be set by a module, so it would have to be added by hand. That is a
worse trade for what it buys, which is why the module takes the simple route
and only takes it where it is needed.

## Building

```sh
./pack.sh path/to/QcomPdInfoRoot.apk
```

The apk is a build artefact and is not kept in this repository; the zip is the
only place the two belong together. CI builds it from the app repository.

### Test builds

Every push and pull request produces an installable zip, under **Actions** on
the run, as the artefact named `qcom_pd_info-testkey-<sha>`. Download it and
flash it as it is - GitHub's own zip is the module zip, not a zip containing
one.

It is signed with `testkey.jks`, which is the public AOSP debug key and
therefore in this repository rather than in a secret. That makes a test build
reproducible by anyone and lets a pull request from a fork produce one, at the
cost of the signature meaning nothing: it says the file was not corrupted, not
where it came from.

**A test build and a release cannot replace each other.** Android refuses an
update whose signature differs from the installed one, so going from one to the
other means uninstalling **USB Power Delivery** first. The module zip itself
replaces fine; it is the app inside it that will not.

Releases are built by the tag workflow with the real key, which CI refuses to
use and the release refuses to run without.

## Licence

Apache 2.0.

## Updating

`module.prop` carries an `updateJson`, so the KernelSU manager offers updates
by itself:

```
updateJson=https://raw.githubusercontent.com/WitAqua-tools/Qcom-PD-Info-Module/main/update.json
```

`update.json` is fetched from the branch rather than from a release, which
makes it the one file that can be wrong without anything failing to build - a
stale version there means the manager either never offers the update, or offers
one and then downloads the old zip. `validate.sh` compares it against
`module.prop` on every run for that reason, and CI fails if they disagree.

The zip's name carries no version on purpose: `releases/latest/download` only
resolves for a fixed name, and a versioned one would mean rewriting
`update.json` to a tag every release.

## Why there is no META-INF

A module zip carries `META-INF/com/google/android/update-binary` only to be
flashable from a custom recovery. Neither manager reads it:

- KernelSU has no recovery installation at all. Its documentation is blunt
  about it - *"KernelSU module is **NOT** compatible for installation in a
  custom Recovery!"* - and the module structure it documents has no META-INF in
  it.
- Magisk's own documentation marks the directory *"Only needed for flashing in
  recovery"*, and its app writes its own `module_installer.sh` out of its
  assets and runs that against the zip rather than reading anything from
  `META-INF`. It says as much: *"When your module is downloaded with the Magisk
  app, `update-binary` will be **forcefully** replaced"*.

So the only thing it would add is recovery flashing, which this module could
not usefully support anyway: `customize.sh` installs the apk with `pm install`,
and there is no package manager in recovery.

Install it from the KernelSU manager. It works under Magisk's manager too - the
scripts here use only what both provide.
