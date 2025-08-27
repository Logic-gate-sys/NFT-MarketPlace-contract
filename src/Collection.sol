//SPDX-License-Identifier: MIT
pragma solidity^0.8.24;

//Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions
//Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/*
 * @title Colletion
 * @author Daniel Kpatamia
 *
 * Collection is designed to be as minimal as possible, and have the logics needed for:
 *  1. minting NFT
 *  2. Buying/Selling NFT
 *  3. Ownership transfer of NTF.
 * 
 * It's identical to any general purpose NFT found expecially for art pieces like NPG,JPEG,JEG etc 
 * The NFTs are designed such that only owner can sell, mint NFTs at anytime
 *
 * @notice This contract is the core of the Collection Factory that deploys clones. It handles all the logic
 * for minting and redeeming NFT, as well as payment for buying and all transactions involved with the NFT tokens minted .
 * @notice This contract is based on the OpenSea NFT system
 */

contract Collection is Initializable, ERC721Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    //error
    error Col_NotEnoughAmountToGetNFT();
    error Collection_NotOwner(address, address);
    error Collection_NotListedForSale();
    error Collection_CannotBuyYourOwnNFT();
    error Collection_NFTNotForSaleOrNotEnoughFunds();
    error Collection_PaymentFailed(address seller, address buyer, uint256 price);
    error Collection_TransferFailed();
    error Collection_MintLimitExceeded(uint256 maxAmount, uint256 totalMinted);

    //state variables
    uint256 private s_tokenCounter;
    mapping(uint256 tokenId => string tokenURI) s_tokenIdToTokenURI;
    mapping(uint256 tokenId => uint128 ethPrice) s_tokenIdToPriceInEth; // listed tokens
    mapping(string token_uri => uint256 tokenId) s_tokenURIToId;
    uint256 private i_maxTokens;
    address private s_owner;
    // contract uri for the contract level metadata
    string  private  i_contract_uri;

    //events
    event Collection_NFTMintedSuccess(address _to, address _from, uint256 _tokenId);
    event Collection_NFTBought(address _from, address _to, uint256 price);
    event Collection_NFTListedForSale(string token_uri, uint256 price);
    event Collection_Received(address _from, uint256 _amount, string note);

    //------------- modifiers --------------------------------------------------------------------
    modifier PayBalanceIfThereIs(uint256 token_id) {
        uint256 price = s_tokenIdToPriceInEth[token_id];
        if (msg.value > price) {
            (bool paidBackBallance,) = payable(msg.sender).call{value: msg.value - price}("");
            if (!paidBackBallance) {
                revert Collection_TransferFailed();
            }
        }
        _;
    }

    modifier NotExceedTotalSupply(uint256 maxAmount, uint256 totalMintedAlready) {
        if (totalMintedAlready > maxAmount) {
            revert Collection_MintLimitExceeded(maxAmount, totalMintedAlready);
        }
        _;
    }
    //------------- intialiser (for construcotor like role) --------------------------------------

    /*
    * @param _owner: adddress of collection owner - whoever deploys a clone throught the Collection Factory owns that clone
    * @param name: The unique name of NFT minted 
    * @param symbol: symbol  of NFT minted
    * @notice: This function will be used in the collection factory to deploy a unique clone of an NFT 
    */
    function initialize(address _owner, string memory name, string memory symbol, uint256 _total_supply,string memory _contract_uri)
        public
        initializer
    {
        //set contract level uri
        i_contract_uri = _contract_uri;
        i_maxTokens = _total_supply; // maximum amount of the collection that can be minted
        s_owner = _owner;
        s_tokenCounter = 0; // intial minted tokens
        __ERC721_init(name, symbol); // intialises an nft with name and symbol
        __Ownable_init(_owner);
    }

    //------------- receive ----------------------------------------------------------------------
    /*
    @notice: It's possible for a transaction without msg.data to hit the contract with Eth transfer: 
    *- In this way we want to leverage and autoPurchase token with funds sent so user does not loss Eth
    */
    // receive() external payable {
    //     _autoPurchaseNFT(msg.sender, msg.value, "");
    //     emit Collection_Received(msg.sender, msg.value, "Call with no data");
    // }

    //------------- public  fuunction ------------------------------------------------------------
    /*
    *@param _tokenURI: the URI from ipfs after uploading file to be minted
    *@notice : This function takes a file URI and mints a unique NFT  for owner: but it first check to see if minted max-cap is exceeded
    */
    function mint(string memory _tokenURI) public onlyOwner nonReentrant NotExceedTotalSupply(i_maxTokens, s_tokenCounter) {
        // token URI is a combination image uri and metadata
        s_tokenCounter += 1; 
        s_tokenIdToTokenURI[s_tokenCounter] = _tokenURI; // create new token
        //store the reverse mapping : uri => id
        s_tokenURIToId[_tokenURI] = s_tokenCounter;
        _safeMint(msg.sender, s_tokenCounter); // mint token id to minter
        emit Collection_NFTMintedSuccess(msg.sender, s_owner, s_tokenCounter);
    }

    /*
    *@param token_id: id of NFT to whose price is to be set for selling
    *@param price: price for which NFT should be initially sold
    *@notice: This function set the price of an NFT to simulate it's readiness for selling 
    */
    function listForSale(uint256 token_id, uint128 price) public {
        string memory token_uri = s_tokenIdToTokenURI[token_id];
        if (msg.sender != ownerOf(token_id)) {
            revert Collection_NotOwner(msg.sender, ownerOf(token_id));
        }
        s_tokenIdToPriceInEth[token_id] = price;
        emit Collection_NFTListedForSale(token_uri, price);
    }

    /*
    *@param token_id: id of NFT to whose price is to be set for selling
    *@notice: This function set the price of an NFT to zero  to say that nft is not for sell 
    */
    function cancelListing(uint256 token_id) public {
        if (msg.sender != ownerOf(token_id)) {
            revert Collection_NotOwner(msg.sender, ownerOf(token_id));
        }
        delete s_tokenIdToPriceInEth[token_id]; // delete
    }

    /*
    *@param _tokenId: unique id of an NFT after it has been minted  
    *@notice : This function takes a token id and an transfer the token to another user upon payment 
    */
    function buy(uint256 _tokenId) public payable PayBalanceIfThereIs(_tokenId) nonReentrant {
        //CHECKS
        if (s_tokenIdToPriceInEth[_tokenId] == 0) {
            revert Collection_NotListedForSale();
        }
        address seller = ownerOf(_tokenId); // current owner
        if (msg.sender == seller) {
            revert Collection_CannotBuyYourOwnNFT();
        }

        uint256 price = s_tokenIdToPriceInEth[_tokenId];

        if (price <= 0 || msg.value > price) {
            revert Collection_NFTNotForSaleOrNotEnoughFunds();
        }

        // EFFECTS
        delete s_tokenIdToPriceInEth[_tokenId]; // remove token from listings

        // Transfer NFT
        _transfer(seller, msg.sender, _tokenId);

        //INTERACIONS
        (bool success,) = payable(seller).call{value: price}(""); // pay seller
        if (!success) {
            revert Collection_PaymentFailed(seller, msg.sender, price);
        }
        // buyer might send more values that price

        emit Collection_NFTBought(seller, msg.sender, price);
    }

    // token uri
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return s_tokenIdToTokenURI[tokenId]; // return the stores uri
    }

   /***
    * @notice: Contract level uri points to a contracts metadata on ipfs
    */
     function contractURI() public view returns(string memory){
        return i_contract_uri;
     }

    //base uri
    function _baseURI() internal pure override returns (string memory) {
        return "data:application/json;base64,";
    }
    // expose total minted tokens in this collection

    function getTotalMintedTokens() public view returns (uint256) {
        return s_tokenCounter;
    }

    //---------------- fallback --------------------------------------------------------------
    /*
    *@notice: Theres is possibility that user may send Eth with data but no actual function calls that match: 
    *- In this way we want to try auto purchase of nft to prevent loss of funds on the part of the user 
    */
    // fallback() external payable {
    //     _autoPurchaseNFT(msg.sender, msg.value, msg.data);
    //     emit Collection_Received(msg.sender, msg.value, "Unexpected call");
    // }
    //------------------ internal functions --------------------------------------------------

    function _autoPurchaseNFT(address buyer, uint256 amount, bytes memory data) internal {
        // check the entire token mappings sell on first price match
        for (uint256 token_id = 0; token_id < s_tokenCounter; token_id++) {
            if (s_tokenIdToPriceInEth[token_id] == amount) {
                _executePurchase(buyer, token_id, amount);
            }
        }
    }
    //execute purchase logic
    function _executePurchase(address buyer, uint256 token_id, uint256 amount) internal {
        address seller = ownerOf(token_id);
        if (seller == msg.sender) {
            revert Collection_CannotBuyYourOwnNFT();
        }
        // REMOVE TOKEN
        delete  s_tokenIdToPriceInEth[token_id];
        _transfer(seller, msg.sender, token_id);
        //pay oner
        (bool success,) = payable(seller).call{value: amount}("");
        if (!success) {
            revert Collection_TransferFailed();
        }
        emit Collection_NFTBought(seller, buyer, amount);
    }

    //-------------- views & pure functions --------------------------------------------------
    function getNextId() public view returns(uint256){
      uint256 nextId = s_tokenCounter + 1;
      return nextId;
    }
}