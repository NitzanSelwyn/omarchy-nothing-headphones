// Kept free of QML imports so the parser can run in a plain JS check.

var MODES = ["off", "transparency", "high", "mid", "low", "adaptive"]

function toArray(values) {
  if (!values) return []
  if (Array.isArray(values)) return values
  var result = []
  for (var i = 0; i < Number(values.length || 0); i++) result.push(values[i])
  return result
}

function label(device) {
  return String(device && (device.deviceName || device.name) || "").trim()
}

function isEar2(device) {
  return /^2c:be:eb:/i.test(String(device && device.address || ""))
    || /nothing\s+ear\s*\(?2\)?/i.test(label(device))
}

function deviceStatus(devices) {
  var list = toArray(devices)
  for (var i = 0; i < list.length; i++) {
    var device = list[i]
    if (!isEar2(device)) continue
    return {
      found: true,
      connected: device.connected === true,
      name: label(device) || "Nothing Ear (2)",
      battery: device.batteryAvailable === true
        ? Math.round(Number(device.battery || 0) * 100)
        : -1
    }
  }
  return { found: false, connected: false, name: "Nothing Ear (2)", battery: -1 }
}

function parseAnc(output) {
  var match = String(output || "").trim().match(/^ANC:\s*([a-z-]+)$/i)
  if (!match) return ""
  var mode = match[1].toLowerCase()
  return MODES.indexOf(mode) === -1 ? "" : mode
}

function batteryText(level) {
  return level < 0 ? "Battery unavailable" : level + "% battery"
}

if (typeof module !== "undefined") {
  module.exports = { MODES, isEar2, deviceStatus, parseAnc, batteryText }
}
