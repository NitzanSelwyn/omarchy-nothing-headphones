# Nothing Ear (2) for Omarchy

An Omarchy Quattro bar plugin for Nothing Ear (2). It shows separate left,
right, and case battery levels and controls all six ANC modes.

Battery data is read by the bundled Python helper using the reverse-engineered
RFCOMM protocol documented by [Something X](https://github.com/SoaOaoS/something-x).
ANC controls use [`ear2ctl`](https://gitlab.com/bharadwaj-raju/ear2ctl).

## Development install

Install the small hardware-specific CLI first:

```bash
cargo install ear2ctl
```

Commit the checkout, then install and enable it through Omarchy:

```bash
omarchy plugin validate "$PWD"
omarchy plugin add "$PWD" --enable --yes
omarchy bar move io.github.nitzanselwyn.nothing-ear-2 --section right
```

After later commits, run
`omarchy plugin update io.github.nitzanselwyn.nothing-ear-2 --yes`.
Left-click opens ANC controls;
right-click opens Omarchy's Bluetooth panel. Use the arrow keys plus Enter, or
press `1` through `6` for a mode and `r` to refresh.

## Check

```bash
node tests/model.test.js
/usr/bin/python3 battery.py --self-test
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml
```

This is unofficial and is not endorsed by Nothing. `ear2ctl` is a separate
GPL-3.0-or-later program; this plugin only invokes its command-line interface.
