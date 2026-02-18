const { ethers } = require("hardhat");

async function main() {
  // 替换为你部署的 UniStake 代理合约地址
  const stakeAddress = "0xe9049fa51a030AdB98bD71eDE21911B08616770A";

  const stakeContract = await ethers.getContractAt("UniStake", stakeAddress);

  // 添加 ETH 质押池（第一个池子必须是 ETH）
  const tx = await stakeContract.addPool(
    ethers.ZeroAddress, // stTokenAddress = 0x0 表示 ETH
    500, // poolWeight
    100, // minDepositAmount (单位: wei)
    20, // unstakeLockedBlocks
    true // withUpdate
  );

  await tx.wait();
  console.log("ETH pool added successfully");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
