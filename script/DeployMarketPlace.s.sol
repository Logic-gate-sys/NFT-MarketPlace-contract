// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {MarketPlace} from "../src/MarketPlace.sol";
import {Collection} from "../src/Collection.sol";
import {CollectionFactory} from "../src/CollectionFactory.sol";
import {MockUSDC} from '../src/MockUSDC.sol';

contract DeployMarketPlace is Script {
    function run() external returns(MarketPlace,CollectionFactory ) {
        // PRIVATE_KEY=0x... PAYMENT_TOKEN=0x... forge script script/DeployMarketPlace.s.sol:DeployMarketPlace --rpc-url <RPC> --broadcast
        MockUSDC paymentToken;

        vm.startBroadcast();
        // Deploy MarketPlace (requires address of ERC20 used for payments);
        paymentToken = new MockUSDC();
        MarketPlace marketPlace = new MarketPlace(address(paymentToken));
        console.log("---Market place deployed at ----- :", address(marketPlace));

        // Deploy Collection implementation (logic/implementation contract)
        Collection collection = new Collection();
        console.log("Collection implementation deployed at:", address(collection));

        // deploy sloth also

        // Deploy factory pointing to the implementation
        CollectionFactory factory = new CollectionFactory(address(collection));
        console.log("CollectionFactory deployed at:", address(factory));
        vm.stopBroadcast();
        return (marketPlace, factory);
    }
}
// ...existing