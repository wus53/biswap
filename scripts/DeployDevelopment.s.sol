// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import "../test/ERC20Mintable.sol";
import "../src/BiswapPool.sol";
import "../src/BiswapManager.sol";
import "../src/BiswapQuoter.sol";

contract DeployDevelopment is Script {
    function run() public {
        uint256 wethBalance = 10 ether;
        uint256 usdcBalance = 100000 ether;
        uint160 currentSqrtP = 5602277097478614198912276234240;
        int24 currentTick = 85176;

        // we define the set of steps that will be executed as the deployment
        // transaction (well, each of the steps will be a separate transaction).
        /// For this, we’re using startBroadcast/endBroadcast cheat codes:
        vm.startBroadcast();

        // Between the broadcast cheat codes, we’ll put the actual
        // deployment steps. First, we need to deploy the tokens:
        // First, we need to deploy the tokens:
        // We cannot deploy the pool without having tokens, so we need
        // to deploy them first. Since we’re deploying to a local development
        // network, we need to deploy the tokens ourselves. In the mainnet and
        // public test networks (Ropsten, Goerli, Sepolia), the tokens are
        // already created. Thus, to deploy to those networks, we’ll need to
        // write network-specific deployment scripts.
        ERC20Mintable token0 = new ERC20Mintable("Wrapped Ether", "WETH", 18);
        ERC20Mintable token1 = new ERC20Mintable("USD Coin", "USDC", 18);

        // next step is to deploy the pool contract:
        BiswapPool pool = new BiswapPool(
            address(token0),
            address(token1),
            currentSqrtP,
            currentTick
        );

        // Next goes Manager contract deployment:
        BiswapManager manager = new BiswapManager();
        BiswapQuoter quoter = new BiswapQuoter();

        // finally, we can mint some amount of ETH and USDC to our address:
        // msg.sender in Foundry scripts is the address that sends transactions
        // within the broadcast block. We’ll be able to set it when running scripts.
        token0.mint(msg.sender, wethBalance);
        token1.mint(msg.sender, usdcBalance);

        vm.stopBroadcast();
        // DEPLOYING DONE

        console.log("WETH address", address(token0));
        console.log("USDC address", address(token1));
        console.log("Pool address", address(pool));
        console.log("Manager address", address(manager));
        console.log("Quoter address", address(quoter));
    }
}
