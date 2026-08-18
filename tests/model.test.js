const assert = require("node:assert/strict")
const Model = require("../Model.js")

const ear2 = {
  address: "2C:BE:EB:69:20:5A",
  name: "Nothing Ear (2)",
  connected: true,
  batteryAvailable: true,
  battery: 0.79
}

assert.equal(Model.isEar2(ear2), true)
assert.deepEqual(Model.deviceStatus([ear2]), {
  found: true,
  connected: true,
  name: "Nothing Ear (2)",
  battery: 79
})
assert.equal(Model.isEar2({ name: "Headphones" }), false)
assert.equal(Model.parseAnc("ANC: transparency\n"), "transparency")
assert.equal(Model.parseAnc("not a mode"), "")
assert.equal(Model.batteryText(-1), "Battery unavailable")

console.log("model.test.js: all checks passed")
