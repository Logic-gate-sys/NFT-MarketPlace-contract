//TEST for collections
//SPDX-License-Identifier:MIT
pragma solidity^0.8.24;

import {DeployCollectionAndCollectionFactory} from '../script/DeployCollectionFactory.s.sol';
import {Test} from 'forge-std/Test.sol';
import {CollectionFactory} from "../src/CollectionFactory.sol";
import {Collection} from "../src/Collection.sol";

contract TestDeployment is Test {
    //error
    error OwnableUnauthorizedAccount(address account);
    error Col_NotEnoughAmountToGetNFT();
    error Collection_NotListedForSale();

    CollectionFactory colFacory;
    DeployCollectionAndCollectionFactory deployScript;
    Collection collection;

    address OWNER = makeAddr("owner");
    address USER1 = makeAddr("user1");
    address USER2 = makeAddr("user2");
    uint256 constant MAX_NFT_LIMIT = 100;
    string constant NAME = "DANO_SOUR";
    string constant SYMBOL = "DASR";
    string constant TOKEN_URI = "ipfs://Qm.../metadata/1.json";
    string constant CONTRACT_URI = "ipfs://Contract./metadata/1.json";

    function setUp() public {
        // deal users
        vm.deal(USER1, 0.1 ether);
        vm.deal(USER2, 20 ether);
        vm.deal(OWNER, 10 ether);
        deployScript = new DeployCollectionAndCollectionFactory();
        colFacory = deployScript.run();
        vm.prank(OWNER); // owner should be the one who created the contract
        collection = Collection(colFacory.createCollection(NAME, SYMBOL, MAX_NFT_LIMIT, CONTRACT_URI));
    }

    // test nft name when created
    function testNFTNameIsCorrect() public {
        string memory name = "DANO_SOUR";
        assertEq(keccak256(bytes(abi.encodePacked(name))), keccak256(bytes(abi.encodePacked(collection.name()))));
    }

    // test minting
    function testMintGivesCorrectTokenURI() public {
        string memory expectedTokenURI = "ipfs://Qm.../metadata/1.json";
        // Now mint with the owner
        vm.prank(OWNER);
        collection.mint(expectedTokenURI);
        // get tokenURI at 0 index
        string memory returnedTokenURI = collection.tokenURI(0);
        // compare returned token uri to expected
        assertEq(keccak256(bytes(expectedTokenURI)), keccak256(bytes(returnedTokenURI)));
    }

    // test owner of a collection nft
    function testOwnerIsCorrect() public {
        string memory expectedTokenURI = "ipfs://Qm.../metadata/1.json";
        // Now mint with the owner
        vm.prank(OWNER);
        collection.mint(expectedTokenURI);
        // compare returned token uri to expected
        assertEq(collection.ownerOf(0), OWNER);
    }

    //test only Owner can mint nft
    function testMintRevertIfCallerIsNotOwner() public {
        string memory expectedTokenURI = "ipfs://Qm.../metadata/1.json";
        // Now mint with the owner
        vm.prank(USER1);
        // Expect revert with correct custom error
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, USER1));
        collection.mint(expectedTokenURI);
    }

    // test nft transfer
    function testTokenTransferSucess() public {
        vm.prank(OWNER);
        collection.mint(TOKEN_URI);
        vm.prank(OWNER);
        // approve spender
        collection.approve(USER1, 0);
        vm.prank(USER1);
        collection.transferFrom(OWNER, USER2, 0);
        //CHECK THAT USER1 NOW HAVE TOKEN IN THEIR WALLET
        address actualOwner = collection.ownerOf(0);
        assertEq(actualOwner, USER2);
    }

    // function test buy
    function testBuyReverIfNotEnoughAmountProvided() public {
        vm.prank(USER1);
        vm.expectRevert();
        collection.buy(0);
    }

    // ensure nft do not sell after unlisting
    function testCancelListing() public {
        vm.prank(OWNER);
        collection.mint("ipfs://metadata/1.json");

        uint256 price = 1 ether;
        vm.prank(OWNER);
        collection.listForSale(0, 0.12 ether);

        vm.prank(OWNER);
        collection.cancelListing(0);

        // Try to buy after canceling should fail
        vm.deal(USER1, 2 ether);
        vm.prank(USER1);
        vm.expectRevert(abi.encodeWithSelector(Collection.Collection_NotListedForSale.selector));
        collection.buy{value: price}(0);
    }
}


