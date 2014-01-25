# estimote2GOM

## About this app

* Ranges iBeacons in defined regions (UUID) and writes the data of the first iBeacon which is in "immediate" distance to the mobile device to the GOM.
* Registers a GOM observer to the iBeacon data and displays the data in the console text field.
* Retrieves the color of the currently tracked iBeacon from the GOM and colors the main view's background accordingly.
* GOM address can be configured in the system settings pane

## Values currently written to GOM

```
/testing/beacons/immediate:UUID
/testing/beacons/immediate:major
/testing/beacons/immediate:minor
```

# Values currently read from GOM

```
/tests/beacons/regions/[UUID]/[major]/[minor]:color = "0.5, 0.3, 0.2, 0.1" (RGBA as float values)
```
