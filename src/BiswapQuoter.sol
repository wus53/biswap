//SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "./interfaces/IBiswapPool.sol";

// we have to simulate a real swap to calculate output amount since
// liquidity is scattered over multiple price ranges.
// we cannot calculate swap amounts with a formula

/// @title BiswapQuoter
/// @notice Quoter is a contract that implements only one public function: quote.
/// Quoter is a universal contract that works with any pool so it takes pool
/// address as a parameter. The other parameters (amountIn and zeroForOne) are
/// required to simulate a swap.
contract BiswapQuoter {
    struct QuoteParams {
        address pool;
        uint256 amountIn;
        bool zeroForOne;
    }

    // The only thing that the contract does is calling swap function of a pool.
    // The call is expected to revert (i.e. throw an error, so that no real transfer
    // of token will happen) we’ll do this in the swap callback below. In the case
    // of a revert, revert reason is decoded and returned; quote will never revert.
    function quote(
        QuoteParams memory params
    )
        public
        returns (uint256 amountOut, uint160 sqrtPriceX96, int24 tickAfter)
    {
        try
            IBiswapPool(params.pool).swap(
                address(this),
                params.zeroForOne,
                params.amountIn,
                // passing only pool address–in the swap callback,
                // we’ll use it to get pool’s slot0 after a swap.
                abi.encode(params.pool)
            )
        {} catch (bytes memory reason) {
            return abi.decode(reason, (uint256, uint160, int24));
        }
    }

    function biswapSwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes memory data
    ) external view {
        address pool = abi.decode(data, (address));

        uint256 amountOut = amount0Delta > 0
            ? uint256(-amount1Delta)
            : uint256(-amount0Delta);
        (uint160 sqrtPriceX96After, int24 tickAfter) = IBiswapPool(pool)
            .slot0();

        assembly {
            // reads the pointer of the first available memory slot
            let ptr := mload(0x40)
            mstore(ptr, amountOut)
            // memory in EVM is organized in 32 byte slots. 0x20 = 32 bytes
            mstore(add(ptr, 0x20), sqrtPriceX96After)
            mstore(add(ptr, 0x40), tickAfter)
            // reverts the call and returns 96 bytes (total length of the
            // values we wrote to memory) of data at address ptr
            revert(ptr, 96)
        }
    }
}
