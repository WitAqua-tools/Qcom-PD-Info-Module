## v0.1.1

- Mount debugfs only where it buys something. A board with Qualcomm's own power
  delivery driver, or an upstream class that already carries the object lists,
  is left alone.

## v0.1.0

- First build. Installs the viewer and mounts debugfs so the charger's object
  list can be read on platforms whose firmware does not report that it can be.
