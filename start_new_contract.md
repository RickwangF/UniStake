# UniStake — ERC20 质押项目合约开发指南

## 目录

1. [项目背景与目标](#1-项目背景与目标)
2. [项目结构规划](#2-项目结构规划)
3. [环境准备与项目搭建](#3-环境准备与项目搭建)
4. [依赖说明](#4-依赖说明)
5. [合约设计 — UniToken (ERC20 代币)](#5-合约设计--unitoken-erc20-代币)
6. [合约设计 — UniStake (质押合约)](#6-合约设计--unistake-质押合约)
7. [部署脚本编写](#7-部署脚本编写)
8. [测试编写 (Foundry)](#8-测试编写-foundry)
9. [本地部署与交互测试](#9-本地部署与交互测试)
10. [部署到 Sepolia 测试网](#10-部署到-sepolia-测试网)
11. [合约验证](#11-合约验证)
12. [常见问题与注意事项](#12-常见问题与注意事项)

---

## 1. 项目背景与目标

**你的背景：**
- 学习过 Solidity 课程，尚未实际编写合约代码
- 熟悉 MetaNodeStake 项目的功能（参考项目）
- 需要通过实际编码来掌握 Solidity 语法和 DeFi 合约开发

**项目目标：**
- 开发一个 ERC20 质押平台：用户质押 ETH 或 ERC20 代币，赚取 UniToken 奖励
- 实现与 MetaNodeStake 相同的功能：多池质押、延迟提款、权重分配奖励
- 使用 UUPS 可升级代理模式
- 部署到 Sepolia 测试网

**你需要编写两个合约：**

| 合约 | 功能 | 对应参考 |
|------|------|----------|
| `UniToken.sol` | ERC20 奖励代币 | MetaNode.sol |
| `UniStake.sol` | 质押合约（UUPS 可升级） | MetaNodeStake.sol |

---

## 2. 项目结构规划

```
UniStake/
├── contracts/
│   ├── UniToken.sol              # ERC20 奖励代币合约
│   └── UniStake.sol              # 质押合约（你手写的核心）
├── scripts/
│   ├── deploy.js                 # 本地完整部署脚本
│   ├── deployUniStake.js         # Sepolia 部署质押合约代理
│   └── addPool.js                # 添加质押池
├── test/
│   └── UniStake.t.sol            # Foundry 测试文件
├── ignition/
│   └── modules/
│       └── UniToken.js           # Hardhat Ignition 部署 UniToken
├── hardhat.config.js             # Hardhat 配置
├── foundry.toml                  # Foundry 配置（可选，用 forge 测试时需要）
├── package.json
├── .env                          # 环境变量（不提交到 git）
├── .gitignore
└── start_new_contract.md         # 本文档
```

---

## 3. 环境准备与项目搭建

### 3.1 前置条件

确保你已安装：
- **Node.js** >= 18.x (`node -v` 检查)
- **npm** 或 **bun**
- **Foundry**（用于 `forge test`）：如未安装，执行 `curl -L https://foundry.paradigm.xyz | bash && foundryup`

### 3.2 初始化项目

```bash
# 1. 进入项目目录
cd /Users/rickwang/Documents/Work/TestCan/React/UniStake

# 2. 初始化 npm 项目
npm init -y

# 3. 安装 Hardhat 2.x（注意：不指定版本会安装 Hardhat 3.x，与本项目不兼容）
#    zsh 中 ^ 是特殊字符，必须加引号
npm install --save-dev "hardhat@^2"

# 4. 初始化 Hardhat 项目（选择 "Create a JavaScript project"）
npx hardhat init
#    选择：Create a JavaScript project
#    项目根目录：回车（默认当前目录）
#    .gitignore：Yes
#    安装依赖：Yes
```

> **注意：** `npx hardhat init` 会自动创建 `contracts/`、`scripts/`、`test/` 目录和示例文件。你可以删除示例文件（如 `Lock.sol`、`Lock.js`）。

### 3.3 安装项目依赖

```bash
# ---- 核心依赖（生产环境） ----
# 注意：zsh 中 ^ 是特殊字符，带 @^ 的版本号必须用引号包裹

# OpenZeppelin 标准合约库（ERC20、AccessControl 等）
npm install "@openzeppelin/contracts@^5.0.2"

# OpenZeppelin 可升级合约库（Initializable、UUPSUpgradeable 等）
npm install "@openzeppelin/contracts-upgradeable@^5.0.2"

# OpenZeppelin Hardhat 升级插件（部署 UUPS 代理用）
npm install "@openzeppelin/hardhat-upgrades@^3.2.1"

# ---- 开发依赖 ----

# Hardhat 工具箱（包含 ethers、chai、verify 等常用插件）
npm install --save-dev @nomicfoundation/hardhat-toolbox

# dotenv（读取 .env 环境变量）
npm install --save-dev dotenv
```

### 3.4 创建配置文件

**hardhat.config.js：**

```javascript
require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
require("@openzeppelin/hardhat-upgrades");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.22",
    settings: {
      optimizer: {
        enabled: false,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {},
    sepolia: {
      url: "https://eth-sepolia.g.alchemy.com/v2/" + process.env.ALCHEMY_API_KEY,
      accounts: [process.env.PRIVATE_KEY],
      gasPrice: 30000000000, // 30 Gwei
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};
```

**.env 文件（不要提交到 git）：**

```env
ALCHEMY_API_KEY=你的_Alchemy_API_Key
PRIVATE_KEY=你的钱包私钥（带Sepolia ETH的测试账户）
ETHERSCAN_API_KEY=你的_Etherscan_API_Key
```

> 获取方式：
> - Alchemy API Key: https://dashboard.alchemy.com/ 注册后创建 Sepolia App
> - Sepolia ETH: https://sepoliafaucet.com/ 领取测试 ETH
> - Etherscan API Key: https://etherscan.io/myapikey 注册后获取

**.gitignore（确保包含以下内容）：**

```
node_modules/
.env
cache/
artifacts/
typechain/
typechain-types/
coverage/
ignition/deployments/chain-31337
.openzeppelin/
```

**foundry.toml（用 forge 跑测试时需要）：**

```toml
[profile.default]
src = "contracts"
out = "out"
libs = ["node_modules"]
```

### 3.5 清理示例文件

```bash
# 删除 Hardhat 自动生成的示例文件
rm -f contracts/Lock.sol
rm -f test/Lock.js
rm -f scripts/deploy.js
rm -f ignition/modules/Lock.js
```

---

## 4. 依赖说明

| 依赖包 | 类型 | 用途 |
|--------|------|------|
| `@openzeppelin/contracts` | 生产 | ERC20 标准实现、SafeERC20、Address、Math 工具库 |
| `@openzeppelin/contracts-upgradeable` | 生产 | 可升级合约基类：Initializable、UUPSUpgradeable、AccessControlUpgradeable、PausableUpgradeable |
| `@openzeppelin/hardhat-upgrades` | 生产 | Hardhat 插件，提供 `upgrades.deployProxy()` 部署 UUPS 代理 |
| `@nomicfoundation/hardhat-toolbox` | 开发 | Hardhat 全家桶（ethers.js、chai 断言、合约验证、gas reporter 等） |
| `hardhat` | 开发 | Solidity 编译、脚本执行、网络管理 |
| `dotenv` | 开发 | 从 `.env` 文件加载环境变量 |

**为什么需要两套 OpenZeppelin？**
- `@openzeppelin/contracts` — 用于普通合约（如 UniToken.sol 使用 `ERC20`）
- `@openzeppelin/contracts-upgradeable` — 用于可升级合约（如 UniStake.sol 使用 `Initializable`、`UUPSUpgradeable` 等），这些合约不能用 `constructor`，必须用 `initialize` 函数

---

## 5. 合约设计 — UniToken (ERC20 代币)

### 功能描述
一个简单的 ERC20 代币，总供应量在部署时一次性铸造给部署者。

### 伪代码

```
// SPDX-License-Identifier: MIT
// Solidity 版本: ^0.8.20

// 导入 OpenZeppelin 的 ERC20 标准实现
// 路径: "@openzeppelin/contracts/token/ERC20/ERC20.sol"

合约 UniToken 继承 ERC20:

    构造函数():
        // 调用 ERC20 父构造函数，传入代币名称和符号
        //   名称: "UniToken"
        //   符号: "UNI"

        // 铸造初始供应量给部署者 (msg.sender)
        // 总量: 10,000,000 个代币
        // 注意: ERC20 默认 18 位小数，所以实际值 = 10000000 * 10^18
        // Solidity 写法: 10000000 * 1e18 或 10_000_000 * 1_000_000_000_000_000_000
        调用 _mint(msg.sender, 10_000_000 * 1e18)
```

### 关键知识点
- `ERC20` 是 OpenZeppelin 提供的标准实现，自带 `transfer`、`approve`、`transferFrom`、`balanceOf` 等函数
- `_mint` 是 ERC20 内部函数，只能在构造函数或合约内部调用
- `1e18` 是 Solidity 的科学计数法，等于 `10^18`

### 你需要写的代码

在 `contracts/UniToken.sol` 中编写，整个合约大约 10 行代码。

---

## 6. 合约设计 — UniStake (质押合约)

这是核心合约，实现完整的质押逻辑。使用 UUPS 可升级代理模式。

### 6.1 整体架构

```
UniStake 合约
├── 继承: Initializable（可升级初始化）
├── 继承: UUPSUpgradeable（UUPS 代理模式）
├── 继承: PausableUpgradeable（暂停功能）
├── 继承: AccessControlUpgradeable（角色权限管理）
│
├── 数据结构
│   ├── Pool（资金池）
│   ├── UnstakeRequest（解质押请求）
│   └── User（用户信息）
│
├── 管理员函数（ADMIN_ROLE）
│   ├── 代币/区块设置
│   ├── 暂停控制
│   └── 资金池管理
│
├── 用户函数
│   ├── depositETH()    — 质押 ETH
│   ├── deposit()       — 质押 ERC20
│   ├── unstake()       — 申请解质押（延迟）
│   ├── withdraw()      — 提取已解锁的质押物
│   └── claim()         — 领取奖励代币
│
└── 内部函数
    ├── _deposit()              — 质押核心逻辑
    ├── _safeUniTokenTransfer() — 安全转账奖励代币
    └── _safeETHTransfer()      — 安全转账 ETH
```

### 6.2 核心数学原理（先理解再写代码）

**奖励累加器模式 (Reward Accumulator Pattern)：**

这是 DeFi 质押合约最核心的算法，目的是高效计算每个用户应得多少奖励，而不需要每个区块都遍历所有用户。

```
核心公式:
  本次可领取总奖励 = (user.stAmount × pool.accUniTokenPerST) / 1e18
                     - user.finishedUniToken
                     + user.pendingUniToken

  说明：
    - user.finishedUniToken: 已结算奖励（每次质押/解质押/领取时重新计算）
    - user.pendingUniToken: 历史累积待领奖励（unstake 时暂存的奖励）

其中：
  池子每份累积奖励 (accUniTokenPerST) 每次更新池子时增加：
    增量 = (区块数 × 每区块全局总奖励 × 池子权重 / 总权重) × 1e18 / 池子总质押量
```

**为什么乘以 1e18？**
Solidity 没有浮点数，`1e18` 相当于给精度放大 18 位，避免整数除法的精度丢失。

**简单举例：**
```
池子总质押: 100 ETH, 用户A质押: 30 ETH
每区块奖励: 10 UniToken, 经过 5 个区块

总奖励 = 10 × 5 = 50 UniToken
每份累积 = 50 × 1e18 / 100 = 0.5 × 1e18

用户A奖励 = 30 × 0.5 × 1e18 / 1e18 = 15 UniToken
```

### 6.3 完整伪代码

```
// SPDX-License-Identifier: MIT
// Solidity 版本: ^0.8.20

// ==================== 导入 ====================
// 从 @openzeppelin/contracts 导入:
//   - IERC20          (ERC20 接口，用于与代币交互)
//   - SafeERC20       (安全的 ERC20 转账，防止不规范代币)
//   - Address          (地址工具库)
//   - Math             (数学工具库，提供 tryMul/tryDiv/tryAdd/trySub 安全运算)
//
// 从 @openzeppelin/contracts-upgradeable 导入:
//   - Initializable                (可升级合约的初始化基类)
//   - UUPSUpgradeable             (UUPS 代理模式)
//   - AccessControlUpgradeable    (角色权限控制)
//   - PausableUpgradeable         (暂停功能)

合约 UniStake 继承 Initializable, UUPSUpgradeable, PausableUpgradeable, AccessControlUpgradeable:

    // ==================== using 声明 ====================
    // using SafeERC20 for IERC20   → 让 IERC20 类型可以直接调用 safeTransfer/safeTransferFrom
    // using Address for address     → 地址工具
    // using Math for uint256        → 让 uint256 可以调用 tryMul/tryDiv 等安全数学运算

    // ==================== 常量 ====================
    常量 ADMIN_ROLE = keccak256("admin_role")      // 管理员角色标识
    常量 UPGRADE_ROLE = keccak256("upgrade_role")   // 升级权限角色标识
    常量 ETH_PID = 0                                // ETH 池子固定为第 0 个

    // ==================== 数据结构 ====================

    结构体 Pool:
        stTokenAddress: address     // 质押代币地址 (address(0) 表示 ETH)
        poolWeight: uint256         // 池子权重（决定该池分得多少奖励）
        lastRewardBlock: uint256    // 上次计算奖励的区块号
        accUniTokenPerST: uint256   // 每份质押累积的奖励（乘以 1e18）
        stTokenAmount: uint256      // 池子内总质押量
        minDepositAmount: uint256   // 最小质押金额
        unstakeLockedBlocks: uint256 // 解质押锁定区块数

    结构体 UnstakeRequest:
        amount: uint256         // 申请解质押的数量
        unlockBlocks: uint256   // 可以提取的区块号

    结构体 User:
        stAmount: uint256           // 用户质押的代币数量
        finishedUniToken: uint256   // 已结算的奖励（用于计算差值）
        pendingUniToken: uint256    // 待领取的奖励累积
        requests: UnstakeRequest[]  // 解质押请求列表

    // ==================== 状态变量 ====================
    startBlock: uint256             // 质押开始区块
    endBlock: uint256               // 质押结束区块
    uniTokenPerBlock: uint256       // 每区块产出的奖励代币数量

    withdrawPaused: bool            // 是否暂停提款
    claimPaused: bool               // 是否暂停领奖

    uniToken: IERC20               // 奖励代币合约引用
    totalPoolWeight: uint256        // 所有池子权重之和
    pool: Pool[]                    // 池子数组
    user: mapping(uint256 => mapping(address => User))  // 池子ID => 用户地址 => 用户信息

    // ==================== 事件 (Events) ====================
    // 事件用于链上日志记录，前端可以监听这些事件
    // 每个状态变更函数都应 emit 对应事件
    //
    // 定义以下事件（参考格式: event 名称(参数类型 indexed 参数名, ...)）：
    //   SetUniToken(IERC20 indexed uniToken)
    //   PauseWithdraw()
    //   UnpauseWithdraw()
    //   PauseClaim()
    //   UnpauseClaim()
    //   SetStartBlock(uint256 indexed startBlock)
    //   SetEndBlock(uint256 indexed endBlock)
    //   SetUniTokenPerBlock(uint256 indexed uniTokenPerBlock)
    //   AddPool(address indexed stTokenAddress, uint256 indexed poolWeight, uint256 indexed lastRewardBlock, uint256 minDepositAmount, uint256 unstakeLockedBlocks)
    //   UpdatePoolInfo(uint256 indexed poolId, uint256 indexed minDepositAmount, uint256 indexed unstakeLockedBlocks)
    //   SetPoolWeight(uint256 indexed poolId, uint256 indexed poolWeight, uint256 totalPoolWeight)
    //   UpdatePool(uint256 indexed poolId, uint256 indexed lastRewardBlock, uint256 totalUniToken)
    //   Deposit(address indexed user, uint256 indexed poolId, uint256 amount)
    //   RequestUnstake(address indexed user, uint256 indexed poolId, uint256 amount)
    //   Withdraw(address indexed user, uint256 indexed poolId, uint256 amount, uint256 indexed blockNumber)
    //   Claim(address indexed user, uint256 indexed poolId, uint256 uniTokenReward)

    // ==================== 修饰器 (Modifiers) ====================

    修饰器 checkPid(_pid):
        // 检查 _pid 是否小于 pool.length，否则 revert "invalid pid"
        // 提示: require(_pid < pool.length, "invalid pid")
        执行函数体 _;

    修饰器 whenNotClaimPaused():
        // 检查 claimPaused 是否为 false
        执行函数体 _;

    修饰器 whenNotWithdrawPaused():
        // 检查 withdrawPaused 是否为 false
        执行函数体 _;

    // ==================== 初始化函数（替代构造函数） ====================

    函数 initialize(_uniToken, _startBlock, _endBlock, _uniTokenPerBlock) public initializer:
        // 1. 参数校验: _startBlock <= _endBlock, _uniTokenPerBlock > 0

        // 2. 调用父合约初始化（重要！可升级合约必须这样做）
        //    __AccessControl_init()
        //    __UUPSUpgradeable_init()

        // 3. 给部署者授予三个角色
        //    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender)
        //    _grantRole(UPGRADE_ROLE, msg.sender)
        //    _grantRole(ADMIN_ROLE, msg.sender)

        // 4. 设置奖励代币
        //    调用 setUniToken(_uniToken)

        // 5. 设置区块范围和每区块奖励
        //    startBlock = _startBlock
        //    endBlock = _endBlock
        //    uniTokenPerBlock = _uniTokenPerBlock

    // UUPS 升级授权（只有 UPGRADE_ROLE 可以升级）
    函数 _authorizeUpgrade(newImplementation) internal onlyRole(UPGRADE_ROLE) override:
        // 空函数体，仅靠 onlyRole 修饰器做权限检查

    // ==================== 管理员函数 ====================

    函数 setUniToken(_uniToken) public onlyRole(ADMIN_ROLE):
        // 设置奖励代币地址
        // emit SetUniToken

    函数 pauseWithdraw() public onlyRole(ADMIN_ROLE):
        // 前置条件: 当前 withdrawPaused 必须为 false
        // 设置 withdrawPaused = true
        // emit PauseWithdraw

    函数 unpauseWithdraw() public onlyRole(ADMIN_ROLE):
        // 前置条件: 当前 withdrawPaused 必须为 true
        // 设置 withdrawPaused = false
        // emit UnpauseWithdraw

    函数 pauseClaim() public onlyRole(ADMIN_ROLE):
        // 类似 pauseWithdraw 的逻辑

    函数 unpauseClaim() public onlyRole(ADMIN_ROLE):
        // 类似 unpauseWithdraw 的逻辑

    函数 setStartBlock(_startBlock) public onlyRole(ADMIN_ROLE):
        // 校验: _startBlock <= endBlock
        // 更新 startBlock
        // emit SetStartBlock

    函数 setEndBlock(_endBlock) public onlyRole(ADMIN_ROLE):
        // 校验: startBlock <= _endBlock
        // 更新 endBlock
        // emit SetEndBlock

    函数 setUniTokenPerBlock(_uniTokenPerBlock) public onlyRole(ADMIN_ROLE):
        // 校验: _uniTokenPerBlock > 0
        // 更新 uniTokenPerBlock
        // emit SetUniTokenPerBlock

    函数 addPool(_stTokenAddress, _poolWeight, _minDepositAmount, _unstakeLockedBlocks, _withUpdate) public onlyRole(ADMIN_ROLE):
        // 规则: 第一个池子(pool.length == 0)必须是 ETH 池(_stTokenAddress == address(0))
        //       后续池子不能是 address(0)
        // 校验: _unstakeLockedBlocks > 0
        // 校验: block.number < endBlock（还没结束）

        // 如果 _withUpdate 为 true，先调用 massUpdatePools() 更新所有池子

        // 计算 lastRewardBlock = max(block.number, startBlock)
        // 累加 totalPoolWeight += _poolWeight

        // 创建新 Pool 并 push 到 pool 数组
        //   stTokenAddress: _stTokenAddress
        //   poolWeight: _poolWeight
        //   lastRewardBlock: lastRewardBlock
        //   accUniTokenPerST: 0
        //   stTokenAmount: 0
        //   minDepositAmount: _minDepositAmount
        //   unstakeLockedBlocks: _unstakeLockedBlocks

        // emit AddPool

    函数 updatePoolInfo(_pid, _minDepositAmount, _unstakeLockedBlocks) public onlyRole(ADMIN_ROLE) checkPid(_pid):
        // 更新指定池子的 minDepositAmount 和 unstakeLockedBlocks
        // emit UpdatePoolInfo

    函数 setPoolWeight(_pid, _poolWeight, _withUpdate) public onlyRole(ADMIN_ROLE) checkPid(_pid):
        // 校验: _poolWeight > 0
        // 如果 _withUpdate，先 massUpdatePools()
        // 更新 totalPoolWeight: 先减去旧权重，再加上新权重
        //   totalPoolWeight = totalPoolWeight - pool[_pid].poolWeight + _poolWeight
        // 更新 pool[_pid].poolWeight = _poolWeight
        // emit SetPoolWeight

    // ==================== 查询函数 (view) ====================

    函数 poolLength() external view returns(uint256):
        // 返回 pool.length

    函数 getMultiplier(_from, _to) public view returns(uint256 multiplier):
        // 计算 [_from, _to) 区间的奖励乘数
        //
        // 1. 校验 _from <= _to
        // 2. 将范围限制在 [startBlock, endBlock] 内:
        //    如果 _from < startBlock: _from = startBlock
        //    如果 _to > endBlock: _to = endBlock
        // 3. 再次校验 _from <= _to
        // 4. multiplier = (_to - _from) * uniTokenPerBlock
        //    使用 tryMul 防止溢出

    函数 pendingUniToken(_pid, _user) external view checkPid returns(uint256):
        // 返回 pendingUniTokenByBlockNumber(_pid, _user, block.number)

    函数 pendingUniTokenByBlockNumber(_pid, _user, _blockNumber) public view checkPid returns(uint256):
        // 获取用户在指定区块的待领奖励
        //
        // 1. 读取 pool 和 user 数据 (用 storage 引用节省 gas)
        // 2. 复制 accUniTokenPerST 到局部变量
        // 3. 如果 _blockNumber > pool.lastRewardBlock 且 stTokenAmount > 0:
        //    a. multiplier = getMultiplier(lastRewardBlock, _blockNumber)
        //    b. uniTokenForPool = multiplier * poolWeight / totalPoolWeight
        //    c. accUniTokenPerST += uniTokenForPool * 1e18 / stTokenAmount
        // 4. 返回: user.stAmount * accUniTokenPerST / 1e18 - user.finishedUniToken + user.pendingUniToken

    函数 stakingBalance(_pid, _user) external view checkPid returns(uint256):
        // 返回 user[_pid][_user].stAmount

    函数 withdrawAmount(_pid, _user) public view checkPid returns(uint256 requestAmount, uint256 pendingWithdrawAmount):
        // 遍历用户的所有 UnstakeRequest
        // requestAmount: 总的解质押请求金额
        // pendingWithdrawAmount: 已解锁可提取的金额（unlockBlocks <= block.number 的）

    // ==================== 用户函数 ====================

    函数 depositETH() public whenNotPaused payable:
        // 1. 获取 ETH 池子 (pool[ETH_PID])
        // 2. 校验: pool.stTokenAddress == address(0)（确保是 ETH 池）
        // 3. _amount = msg.value（用户发送的 ETH 数量）
        // 4. 校验: _amount >= pool.minDepositAmount
        // 5. 调用内部函数 _deposit(ETH_PID, _amount)

    函数 deposit(_pid, _amount) public whenNotPaused checkPid(_pid):
        // 1. 校验: _pid != 0（非 ETH 池）
        // 2. 校验: _amount > pool.minDepositAmount
        // 3. 如果 _amount > 0:
        //    使用 safeTransferFrom 将代币从用户转到本合约
        //    IERC20(pool.stTokenAddress).safeTransferFrom(msg.sender, address(this), _amount)
        // 4. 调用内部函数 _deposit(_pid, _amount)

    函数 unstake(_pid, _amount) public whenNotPaused checkPid whenNotWithdrawPaused:
        // 1. 获取 pool 和 user 的 storage 引用
        // 2. 校验: user.stAmount >= _amount（余额足够）
        // 3. 调用 updatePool(_pid) 更新池子奖励
        // 4. 计算待领奖励:
        //    pendingUniToken_ = user.stAmount * pool.accUniTokenPerST / 1e18 - user.finishedUniToken
        // 5. 如果 pendingUniToken_ > 0:
        //    user.pendingUniToken += pendingUniToken_（累加到待领取）
        // 6. 如果 _amount > 0:
        //    a. user.stAmount -= _amount
        //    b. 创建 UnstakeRequest 并 push 到 user.requests:
        //       amount: _amount
        //       unlockBlocks: block.number + pool.unstakeLockedBlocks
        // 7. pool.stTokenAmount -= _amount
        // 8. 重新计算: user.finishedUniToken = user.stAmount * pool.accUniTokenPerST / 1e18
        // 9. emit RequestUnstake

    函数 withdraw(_pid) public whenNotPaused checkPid whenNotWithdrawPaused:
        // 1. 获取 pool 和 user 的 storage 引用
        // 2. 遍历 user.requests，找出已解锁的请求（unlockBlocks <= block.number）
        //    累加 pendingWithdraw（可提取总额）
        //    记录 popNum（要移除的请求数量）
        // 3. 移除已处理的请求（从数组前端移除）
        //    方法: 将后面的元素前移，然后 pop 掉末尾多余的
        //    for (i = 0; i < length - popNum; i++):
        //        requests[i] = requests[i + popNum]
        //    for (i = 0; i < popNum; i++):
        //        requests.pop()
        // 4. 如果 pendingWithdraw > 0:
        //    如果是 ETH 池 (stTokenAddress == address(0)):
        //        调用 _safeETHTransfer(msg.sender, pendingWithdraw)
        //    否则:
        //        IERC20(stTokenAddress).safeTransfer(msg.sender, pendingWithdraw)
        // 5. emit Withdraw

    函数 claim(_pid) public whenNotPaused checkPid whenNotClaimPaused:
        // 1. 获取 pool 和 user 的 storage 引用
        // 2. 调用 updatePool(_pid) 更新池子
        // 3. 计算总待领:
        //    pendingUniToken_ = user.stAmount * pool.accUniTokenPerST / 1e18
        //                     - user.finishedUniToken
        //                     + user.pendingUniToken
        // 4. 如果 pendingUniToken_ > 0:
        //    a. user.pendingUniToken = 0（清零待领）
        //    b. 调用 _safeUniTokenTransfer(msg.sender, pendingUniToken_)
        // 5. 更新: user.finishedUniToken = user.stAmount * pool.accUniTokenPerST / 1e18
        // 6. emit Claim

    // ==================== 公共函数 ====================

    函数 updatePool(_pid) public checkPid:
        // 更新指定池子的奖励累加器
        //
        // 1. 获取 pool 的 storage 引用
        // 2. 如果 block.number <= pool.lastRewardBlock: 直接返回（不需要更新）
        // 3. 计算该池子在这段时间的总奖励:
        //    totalUniToken = getMultiplier(lastRewardBlock, block.number) * poolWeight / totalPoolWeight
        //    提示: 使用 tryMul 和 tryDiv 防止溢出
        // 4. 如果池子有质押量 (stTokenAmount > 0):
        //    pool.accUniTokenPerST += totalUniToken * 1e18 / stTokenAmount
        //    提示: 先乘 1e18 再除，使用 tryMul/tryDiv
        // 5. 更新 pool.lastRewardBlock = block.number
        // 6. emit UpdatePool

    函数 massUpdatePools() public:
        // 遍历所有池子，对每个调用 updatePool(pid)

    // ==================== 内部函数 ====================

    函数 _deposit(_pid, _amount) internal:
        // 核心质押逻辑（被 depositETH 和 deposit 调用）
        //
        // 1. 获取 pool 和 user 的 storage 引用
        // 2. 调用 updatePool(_pid) 更新池子奖励
        // 3. 如果用户已有质押 (user.stAmount > 0):
        //    a. 计算 accST = user.stAmount * pool.accUniTokenPerST / 1e18
        //    b. pendingUniToken_ = accST - user.finishedUniToken
        //    c. 如果 pendingUniToken_ > 0: user.pendingUniToken += pendingUniToken_
        //    提示: 使用 tryMul/tryDiv/trySub/tryAdd 进行安全运算
        // 4. 如果 _amount > 0:
        //    user.stAmount += _amount
        // 5. pool.stTokenAmount += _amount
        // 6. 重新计算: user.finishedUniToken = user.stAmount * pool.accUniTokenPerST / 1e18
        // 7. emit Deposit

    函数 _safeUniTokenTransfer(_to, _amount) internal:
        // 安全转账奖励代币
        // 为什么需要"安全"？因为舍入误差可能导致实际余额略少于计算值
        //
        // 1. 获取合约持有的 uniToken 余额: uniTokenBal = uniToken.balanceOf(address(this))
        // 2. 如果 _amount > uniTokenBal:
        //    转账 uniTokenBal（转合约里所有的）
        //    否则:
        //    转账 _amount

    函数 _safeETHTransfer(_to, _amount) internal:
        // 安全转账 ETH
        //
        // 1. 使用低级 call 发送 ETH:
        //    (bool success, bytes memory data) = _to.call{value: _amount}("")
        // 2. require(success, "ETH transfer call failed")
        // 3. 如果 data.length > 0:
        //    require(abi.decode(data, (bool)), "ETH transfer did not succeed")
```

### 6.4 编码建议（按此顺序写）

建议你按以下顺序编写 `UniStake.sol`，每写完一部分就编译测试：

| 步骤 | 内容 | 验证方式 |
|------|------|----------|
| 1 | 写 import 语句和合约声明（继承） | `npx hardhat compile` |
| 2 | 写常量、数据结构、状态变量 | `npx hardhat compile` |
| 3 | 写事件和修饰器 | `npx hardhat compile` |
| 4 | 写 initialize 和 _authorizeUpgrade | `npx hardhat compile` |
| 5 | 写管理员函数 | `npx hardhat compile` |
| 6 | 写 getMultiplier 和 view 函数 | `npx hardhat compile` |
| 7 | 写 updatePool 和 massUpdatePools | `npx hardhat compile` |
| 8 | 写 _deposit 内部函数 | `npx hardhat compile` |
| 9 | 写 depositETH 和 deposit | 编写测试 + `forge test` |
| 10 | 写 unstake | 编写测试 + `forge test` |
| 11 | 写 withdraw | 编写测试 + `forge test` |
| 12 | 写 claim | 编写测试 + `forge test` |
| 13 | 写 _safeUniTokenTransfer 和 _safeETHTransfer | 全量测试 |

---

## 7. 部署脚本编写

### 7.1 本地完整部署 (`scripts/deploy.js`)

```javascript
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
  console.log("Transferred", ethers.formatEther(tokenAmount), "UniToken to stake contract");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
```

### 7.2 Ignition 部署 UniToken (`ignition/modules/UniToken.js`)

```javascript
const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("UniTokenModule", (m) => {
  const uniToken = m.contract("UniToken");
  return { uniToken };
});
```

### 7.3 Sepolia 部署质押合约 (`scripts/deployUniStake.js`)

```javascript
const { ethers, upgrades } = require("hardhat");

async function main() {
  // 替换为你在 Sepolia 上部署的 UniToken 地址
  const uniTokenAddress = "你部署UniToken后获得的地址";
  const startBlock = 你选择的起始区块号;     // 可以用 https://sepolia.etherscan.io 查当前区块
  const endBlock = startBlock + 3000000;      // 大约持续 3,000,000 个区块
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
```

### 7.4 添加池子 (`scripts/addPool.js`)

```javascript
const { ethers } = require("hardhat");

async function main() {
  // 替换为你部署的 UniStake 代理合约地址
  const stakeAddress = "你部署UniStake后获得的代理地址";

  const stakeContract = await ethers.getContractAt("UniStake", stakeAddress);

  // 添加 ETH 质押池（第一个池子必须是 ETH）
  const tx = await stakeContract.addPool(
    ethers.ZeroAddress,  // stTokenAddress = 0x0 表示 ETH
    500,                 // poolWeight
    100,                 // minDepositAmount (单位: wei)
    20,                  // unstakeLockedBlocks
    true                 // withUpdate
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
```

---

## 8. 测试编写 (Foundry)

测试使用 Foundry 的 `forge test` 运行。在 `test/` 目录下创建 `.t.sol` 文件。

**需要先创建一个测试用 Mock 合约** `contracts/shared/MockUniToken.sol`：

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// 这个与 UniToken 完全一样，只是名字不同方便测试 import
contract UniToken is ERC20 {
    constructor() ERC20("UniToken", "UNI") {
        _mint(msg.sender, 10_000_000 * 1e18);
    }
}
```

> 注意: 测试文件中 import 这个 Mock 合约，合约名叫 `UniToken`；而 `contracts/UniToken.sol` 中你的合约名叫 `UniToken`。如果名字冲突，可以将 Mock 文件中的合约改名为 `MockUniToken`，或使用 `import {UniToken as MockUniToken}` 的方式导入。

**测试文件框架** `test/UniStake.t.sol`：

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {UniStake} from "../contracts/UniStake.sol";
import {UniToken} from "../contracts/UniToken.sol";
// 或者用 Mock: import {MockUniToken} from "../contracts/shared/MockUniToken.sol";

contract UniStakeTest is Test {
    UniStake uniStake;
    UniToken uniToken;

    // 接收 ETH 的回退函数（测试合约需要能接收 ETH）
    fallback() external payable {}
    receive() external payable {}

    function setUp() public {
        // 每个测试执行前都会调用
        // 1. 部署 UniToken
        // 2. 部署 UniStake（直接 new，不走代理）
        // 3. 调用 uniStake.initialize(uniToken, startBlock, endBlock, perBlock)
    }

    function test_AddPool() public {
        // 测试添加 ETH 池子
        // 调用 uniStake.addPool(address(0), 100, 100, 100, true)
        // 验证池子数据是否正确
    }

    function test_DepositETH() public {
        // 先添加池子
        // 调用 depositETH{value: amount}()
        // 验证用户质押量和池子总量
    }

    function test_Unstake() public {
        // 先质押，推进区块 (vm.roll)，然后解质押
        // 验证用户质押量减少、pendingUniToken 增加
    }

    function test_Withdraw() public {
        // 先质押 → 解质押 → 推进区块过锁定期 → 提取
        // 验证 ETH 余额变化
    }

    function test_Claim() public {
        // 先质押 → 推进区块 → 领取奖励
        // 验证 UniToken 余额增加
    }
}
```

**运行测试：**

```bash
# 运行所有测试
forge test

# 运行单个测试（带详细输出）
forge test --match-test test_AddPool -vvv

# 运行并显示 gas 消耗
forge test --gas-report
```

---

## 9. 本地部署与交互测试

在部署到 Sepolia 之前，先在本地验证完整流程。

### 9.1 编译合约

```bash
npx hardhat compile
```

确保无报错后再进行部署。

### 9.2 启动本地节点

```bash
# 终端 1：启动 Hardhat 本地节点（保持运行，不要关闭）
npx hardhat node
```

启动后会输出 20 个测试账户，每个初始 10000 ETH。关闭终端 1 后所有部署数据清空。

### 9.3 部署合约

```bash
# 终端 2（新开一个终端窗口）：
npx hardhat run scripts/deploy.js --network localhost
```

输出示例：

```
UniToken deployed to: 0x5FbDB2315678afecb367f032d93F642f64180aa3
UniStake (proxy) deployed to: 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
Transferred 10000000.0 UniToken to stake contract
```

记下这两个地址，后续交互需要用到。

### 9.4 进入交互式 Console

```bash
# 终端 2：
npx hardhat console --network localhost
```

### 9.5 完整测试流程

在 console 中逐步执行以下命令：

```javascript
// ===== 1. 初始化 =====

// 获取合约实例（替换为你实际的部署地址）
const stake = await ethers.getContractAt("UniStake", "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0");
const token = await ethers.getContractAt("UniToken", "0x5FbDB2315678afecb367f032d93F642f64180aa3");
const [admin] = await ethers.getSigners();

// ===== 2. 添加 ETH 池子 =====

// 参数: stTokenAddress=0x0(ETH), poolWeight=500, minDeposit=100wei, unstakeLock=20块, withUpdate=true
await stake.addPool(ethers.ZeroAddress, 500, 100, 20, true);

// 验证池子数量
await stake.poolLength();
// 输出: 1n

// ===== 3. 质押 ETH =====

await stake.depositETH({ value: ethers.parseEther("1") });

// 验证质押余额
ethers.formatEther(await stake.stakingBalance(0, admin.address));
// 输出: '1.0'

// ===== 4. 推进区块，测试奖励 =====

// 推进 100 个区块（参数为十六进制: 0x64 = 100）
await network.provider.send("hardhat_mine", ["0x64"]);

// 查看待领奖励
ethers.formatEther(await stake.pendingUniToken(0, admin.address));
// 输出: '100.0'（100 区块 × 每区块 1 UniToken）

// 推进更多区块
await network.provider.send("hardhat_mine", ["0x64"]);
ethers.formatEther(await stake.pendingUniToken(0, admin.address));
// 输出: '200.0'

// ===== 5. 领取奖励（claim） =====

// 领取奖励（不影响质押）
await stake.claim(0);

// 查看 admin 的 UniToken 余额（会比查询时多 1，因为 claim 交易本身占 1 个区块）
ethers.formatEther(await token.balanceOf(admin.address));

// ===== 6. 解质押（unstake） =====

// 申请解质押 0.5 ETH
await stake.unstake(0, ethers.parseEther("0.5"));

// 验证质押余额减少
ethers.formatEther(await stake.stakingBalance(0, admin.address));
// 输出: '0.5'

// ===== 7. 推进区块，跳过锁定期 =====

// addPool 时设的 unstakeLockedBlocks = 20，推进 20 个区块（0x14 = 20）
await network.provider.send("hardhat_mine", ["0x14"]);

// ===== 8. 提取质押物（withdraw） =====

await stake.withdraw(0);

// 查看 ETH 余额（应接近 9999.5 ETH，差额为 gas 费）
ethers.formatEther(await ethers.provider.getBalance(admin.address));
```

### 9.6 推进区块常用值

`hardhat_mine` 参数为十六进制：

| 区块数 | 十六进制 | 命令 |
|--------|----------|------|
| 10 | `0xa` | `await network.provider.send("hardhat_mine", ["0xa"]);` |
| 20 | `0x14` | `await network.provider.send("hardhat_mine", ["0x14"]);` |
| 50 | `0x32` | `await network.provider.send("hardhat_mine", ["0x32"]);` |
| 100 | `0x64` | `await network.provider.send("hardhat_mine", ["0x64"]);` |
| 1000 | `0x3e8` | `await network.provider.send("hardhat_mine", ["0x3e8"]);` |

### 9.7 注意事项

- 每笔交易（非 view 函数调用）都会推进 1 个区块，所以实际奖励可能比查询时多 1
- `console` 中赋值语句输出 `undefined` 是正常的，变量已赋值成功
- `view` 函数（如 `pendingUniToken`、`stakingBalance`）不消耗 gas，可以随意调用
- 关闭终端 1 的 `hardhat node` 后所有数据清空，需要重新部署

---

## 10. 部署到 Sepolia 测试网

按以下顺序执行：

```bash
# 步骤 1: 编译合约
npx hardhat compile

# 步骤 2: 部署 UniToken（使用 Ignition）
npx hardhat ignition deploy ./ignition/modules/UniToken.js --network sepolia
# 记录输出的 UniToken 合约地址

# 步骤 3: 修改 scripts/deployUniStake.js 中的 uniTokenAddress
# 填入步骤 2 得到的地址

# 步骤 4: 部署 UniStake 代理合约
npx hardhat run scripts/deployUniStake.js --network sepolia
# 记录输出的代理合约地址

# 步骤 5: 修改 scripts/addPool.js 中的 stakeAddress
# 填入步骤 4 得到的代理合约地址

# 步骤 6: 添加 ETH 质押池
npx hardhat run scripts/addPool.js --network sepolia

# 步骤 7: 转 UniToken 到质押合约作为奖励池
# 需要自己写一个脚本或用 Etherscan 手动操作
```

---

## 11. 合约验证

部署后，在 Etherscan 上验证合约源码：

```bash
# 验证 UniToken
npx hardhat verify --network sepolia 你的UniToken地址

# 验证 UniStake 实现合约（代理合约会自动指向实现）
npx hardhat verify --network sepolia 你的UniStake实现地址
```

> 注意: UUPS 代理合约的验证比较特殊。`@openzeppelin/hardhat-upgrades` 部署代理时会同时部署一个实现合约(Implementation)。你需要在 `.openzeppelin/sepolia.json` 文件中找到实现合约地址进行验证。

---

## 12. 常见问题与注意事项

### Solidity 语法要点

| 概念 | 说明 |
|------|------|
| `storage` vs `memory` | `storage` 引用直接操作链上数据（gas 低），`memory` 是内存副本 |
| `msg.sender` | 调用合约的地址 |
| `msg.value` | 调用时发送的 ETH 数量（wei） |
| `block.number` | 当前区块号 |
| `address(this)` | 合约本身的地址 |
| `address(0)` / `address(0x0)` | 零地址，用于表示 ETH（不是 ERC20 代币） |
| `1 ether` / `1e18` | 10^18 wei，Solidity 内置单位 |
| `payable` | 函数可以接收 ETH |
| `require(条件, "错误信息")` | 条件不满足时回滚交易 |
| `emit 事件名(参数)` | 触发事件，记录到链上日志 |

### 常见坑

1. **可升级合约不能有 constructor** — 必须用 `initialize` 函数 + `initializer` 修饰器
2. **Hardhat Ignition 生成文件名** — 可能自动命名为 `Rcc.js`，需要手动改名
3. **第一个池子必须是 ETH** — `addPool` 有这个硬性规则
4. **不要重复添加同一个质押代币** — 会导致奖励计算错误
5. **SafeERC20** — 总是用 `safeTransfer` / `safeTransferFrom` 代替原生的 `transfer` / `transferFrom`
6. **Gas 优化** — 用 `storage` 引用而非 `memory` 复制来读写状态变量
7. **整数溢出** — Solidity 0.8+ 默认检查溢出，但用 `Math.tryMul` 等可以更优雅地处理

### 开发工作流（推荐）

```
编写代码 → npx hardhat compile → 修复编译错误
    → 编写测试 → forge test → 修复逻辑错误
    → 本地部署测试 → npx hardhat run scripts/deploy.js
    → Sepolia 部署 → 验证合约 → 前端对接
```

### 有用的参考链接

- [Solidity 官方文档](https://docs.soliditylang.org/)
- [OpenZeppelin Contracts 文档](https://docs.openzeppelin.com/contracts/5.x/)
- [Hardhat 文档](https://hardhat.org/docs)
- [Foundry Book](https://book.getfoundry.sh/)
- [Sepolia Etherscan](https://sepolia.etherscan.io/)
- [Alchemy Dashboard](https://dashboard.alchemy.com/)
