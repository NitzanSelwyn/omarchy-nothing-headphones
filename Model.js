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

function isSupportedDevice(device) {
  var name = label(device)
  return /^2c:be:eb:/i.test(String(device && device.address || ""))
    || /^(nothing\s+)?ear(?:\s|\(|$)/i.test(name)
    || /^cmf\b.*\b(buds?|neckband)\b/i.test(name)
}

function deviceStatus(devices) {
  var list = toArray(devices)
  for (var connected = 1; connected >= 0; connected--) {
    for (var i = 0; i < list.length; i++) {
      var device = list[i]
      if (!isSupportedDevice(device) || Number(device.connected === true) !== connected) continue
      return {
        found: true,
        connected: device.connected === true,
        address: String(device.address || ""),
        name: label(device) || "Nothing Earbuds",
        battery: device.batteryAvailable === true
          ? Math.round(Number(device.battery || 0) * 100)
          : -1
      }
    }
  }
  return { found: false, connected: false, address: "", name: "Nothing Earbuds", battery: -1 }
}

function modeOptions(name) {
  var value = String(name || "")
  if (/ear\s*\((stick|open)\)/i.test(value)) return []
  var common = [
    { value: "off", label: "Off" },
    { value: "transparency", label: "Transparency" },
    { value: "high", label: "ANC" }
  ]
  if (!/ear\s*\(?2\)?/i.test(value)) return common
  return common.concat([
    { value: "mid", label: "Mid" },
    { value: "low", label: "Low" },
    { value: "adaptive", label: "Adaptive" }
  ])
}

function parseStatus(output) {
  var parsed
  try {
    parsed = JSON.parse(String(output || ""))
  } catch (e) {
    return { left: -1, right: -1, case: -1, anc: "" }
  }
  function level(value) {
    return typeof value === "number" && Number.isInteger(value) && value >= 0 && value <= 100
      ? value : -1
  }
  var anc = String(parsed.anc || "").toLowerCase()
  return {
    left: level(parsed.left),
    right: level(parsed.right),
    case: level(parsed.case),
    anc: MODES.indexOf(anc) === -1 ? "" : anc
  }
}

function batterySummary(left, right, caseLevel) {
  return "L " + (left < 0 ? "--" : left + "%")
    + "  R " + (right < 0 ? "--" : right + "%")
    + "  Case " + (caseLevel < 0 ? "--" : caseLevel + "%")
}

if (typeof module !== "undefined") {
  module.exports = {
    MODES, isSupportedDevice, deviceStatus, modeOptions, parseStatus, batterySummary
  }
}
