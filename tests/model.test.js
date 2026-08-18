const assert = require("node:assert/strict")
const Model = require("../Model.js")

const ear2 = {
  address: "2C:BE:EB:69:20:5A",
  name: "Nothing Ear (2)",
  connected: true,
  batteryAvailable: true,
  battery: 0.79
}

assert.equal(Model.isSupportedDevice(ear2), true)
assert.deepEqual(Model.deviceStatus([ear2]), {
  found: true,
  connected: true,
  address: "2C:BE:EB:69:20:5A",
  name: "Nothing Ear (2)",
  battery: 79
})
assert.equal(Model.isSupportedDevice({ name: "CMF Buds Pro" }), true)
assert.equal(Model.isSupportedDevice({ name: "Headphones" }), false)
assert.equal(Model.deviceStatus([
  { name: "Ear (2)", connected: false, address: "2C:BE:EB:00:00:01" },
  { name: "CMF Buds Pro", connected: true, address: "AA:BB:CC:DD:EE:FF" }
]).name, "CMF Buds Pro")
assert.deepEqual(Model.parseStatus('{"left":80,"right":72,"case":90,"anc":"high"}'), {
  left: 80, right: 72, case: 90, anc: "high"
})
assert.deepEqual(Model.parseStatus('{"left":101,"right":null,"anc":"bogus"}'), {
  left: -1, right: -1, case: -1, anc: ""
})
assert.equal(Model.modeOptions("Ear (stick)").length, 0)
assert.deepEqual(Model.modeOptions("CMF Buds Pro").map(mode => mode.value), [
  "off", "transparency", "high"
])
assert.equal(Model.modeOptions("Ear (2)").length, 6)
assert.equal(Model.batterySummary(80, 72, -1), "L 80%  R 72%  Case --")

console.log("model.test.js: all checks passed")
