// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract UniToken is ERC20 {
    constructor() ERC20("UniToken", "UNI") {
        _mint(msg.sender, 10000000 * 1_000_000_000_000_000_000);
    }
}
