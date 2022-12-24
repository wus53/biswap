// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

interface IBiswapMintCallback {
    function biswapMintCallback(uint256 amount0, uint256 amount1) external;
}
