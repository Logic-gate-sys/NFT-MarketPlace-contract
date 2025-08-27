//collection factory
//SPDX-License-Identifier: MIT
pragma solidity^0.8.24;
/* 
 Deployment Order
 1. Deploy Collection contract as logic
 2. Deploy CollectionFactory with the logic address as constructor arg
 3. Call createCollection(name, symbol) to deploy clones
*/

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volatility coin
// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions
// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Collection} from "./Collection.sol";

/*
 * @title DSCEngine
 * @author Daniel Kpatamia
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 * This is a stablecoin with the properties:
 * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
 *
 * Our DSC system should always be "overcollateralized". At no point, should the value of
 * all collateral < the $ backed value of all the DSC.
 *
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic
 * for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS system
 */

contract CollectionFactory {
    address public implementation;
    mapping(address user => address[] collections) public user_collections;

    event CollectionCreated(address indexed creator, address indexed collection);

    constructor(address _implementation) {
        implementation = _implementation; // address of the deploy collection contract
    }

    /*
    * @param tokenCollateralAddress: the address of the token to deposit as collateral
    * @param amountCollateral: The amount of collateral to deposit
    * @param amountDscToMint: The amount of DecentralizedStableCoin to mint
    * @notice: This function will deposit your collateral and mint DSC in one transaction
    */
    function createCollection(
        string memory name,
        string memory symbol,
        uint256 total_supply,
        string memory contract_uri
    ) external returns (address) {
        address clone = Clones.clone(implementation);
        Collection(clone).initialize(msg.sender, name, symbol, total_supply, contract_uri);
        user_collections[msg.sender].push(clone);
        emit CollectionCreated(msg.sender, clone);
        return clone;
    }

    function getCollections() external view returns (address[] memory) {
        return user_collections[msg.sender];
    }
}


