const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("UniTokenModule", (m) => {
  const uniToken = m.contract("UniToken");
  return { uniToken };
});
