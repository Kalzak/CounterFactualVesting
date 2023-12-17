// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import { ERC20 } from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    
    constructor() ERC20("TST", "Test Token") {}

    function mint(address recipient, uint256 amount) external {
        _mint(recipient, amount);
    }

}
