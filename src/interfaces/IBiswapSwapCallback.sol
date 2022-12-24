// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

interface IBiswapSwapCallback {
    function biswapSwapCallback(int256 amount0, int256 amount1, bytes calldata data) external;
}
