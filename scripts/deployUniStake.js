const { ethers, upgrades } = require("hardhat");

async function main() {
  // 替换为你在 Sepolia 上部署的 UniToken 地址
  const uniTokenAddress = "0xf22AeF736184fE67858764D3e07B8F01d57B7145";
  const startBlock = 10283692; // 可以用 https://sepolia.etherscan.io 查当前区块
  const endBlock = startBlock + 3000000; // 大约持续 3,000,000 个区块
  const uniTokenPerBlock = ethers.parseUnits("0.02", 18); // 每区块 0.02 个 UniToken

  const UniStake = await ethers.getContractFactory("UniStake");
  const stake = await upgrades.deployProxy(
    UniStake,
    [uniTokenAddress, startBlock, endBlock, uniTokenPerBlock],
    { initializer: "initialize" }
  );

  await stake.waitForDeployment();
  console.log("UniStake (proxy) deployed to:", await stake.getAddress());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
