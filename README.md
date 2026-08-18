# Nothing Ear (2) for Omarchy

An Omarchy Shell bar plugin for Nothing Ear (2). The first version shows the
BlueZ connection/battery state and controls all six ANC modes through
[`ear2ctl`](https://gitlab.com/bharadwaj-raju/ear2ctl).

## Development install

Install the small hardware-specific CLI first:

```bash
cargo install ear2ctl
```

Then link this checkout into Omarchy and enable it:

```bash
ln -s "$PWD" ~/.config/omarchy/plugins/nitzan.nothing-ear-2
omarchy plugin validate "$PWD"
omarchy plugin enable nitzan.nothing-ear-2
omarchy bar move nitzan.nothing-ear-2 --section right
```

The Shell reloads plugin files automatically. Left-click opens ANC controls;
right-click opens Omarchy's Bluetooth panel. Use the arrow keys plus Enter, or
press `1` through `6` for a mode and `r` to refresh.

## Check

```bash
node tests/model.test.js
omarchy plugin validate .
```

This is unofficial and is not endorsed by Nothing. `ear2ctl` is a separate
GPL-3.0-or-later program; this plugin only invokes its command-line interface.
