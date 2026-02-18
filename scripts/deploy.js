// scripts/deploy.js
const { ethers, upgrades } = require("hardhat");

async function main() {
  const [signer] = await ethers.getSigners();

  // 1. 部署 UniToken
  const UniToken = await ethers.getContractFactory("UniToken");
  const uniToken = await UniToken.deploy();
  await uniToken.waitForDeployment();
  const uniTokenAddress = await uniToken.getAddress();
  console.log("UniToken deployed to:", uniTokenAddress);

  // 2. 部署 UniStake 代理合约
  const UniStake = await ethers.getContractFactory("UniStake");
  const startBlock = 1;
  const endBlock = 999999999999;
  const uniTokenPerBlock = ethers.parseUnits("1", 18); // 每区块 1 个 UniToken

  const stake = await upgrades.deployProxy(
    UniStake,
    [uniTokenAddress, startBlock, endBlock, uniTokenPerBlock],
    { initializer: "initialize" }
  );
  await stake.waitForDeployment();
  const stakeAddress = await stake.getAddress();
  console.log("UniStake (proxy) deployed to:", stakeAddress);

  // 3. 将所有 UniToken 转到质押合约（作为奖励池）
  const tokenAmount = await uniToken.balanceOf(signer.address);
  const tx = await uniToken.connect(signer).transfer(stakeAddress, tokenAmount);
  await tx.wait();
  console.log(
    "Transferred",
    ethers.formatEther(tokenAmount),
    "UniToken to stake contract"
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
