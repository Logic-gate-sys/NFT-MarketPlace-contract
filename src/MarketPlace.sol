// ...existing code...
//SPDX-License-Identifier:MIT
pragma solidity^0.8.24;


import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title NFT-MarketPlace
 * @author Daniel Kwasi Kpatamia  
 * @notice This contract is the main logic for market place application. This contract takes an ERC-20 token and the platform compliant
 *  token that is supported by all transactions. Buying,Selling,Listing of nfts on the marketplace incurs charges that are calculated and
 * transfered from the transaction initialisers account. 
 * @dev This contract expect USDC as the main token for transactions : passed to the constructor 
 * The marketplace has these main features that it supports :
 *   -Buying/Selling NFT
 *   -Listing/Unlisting NFT
 *   -Updating Listing
 *   -Deleting listing 
 */
contract MarketPlace is ReentrancyGuard{
    using SafeERC20 for IERC20; // safe 
    //------------------------------- custom errors --------------------------------------------
    error MarketPlace_NotOwnerOfNFT();
    error MarketPlace_NFTAlreadyListed(address tokenAddress, uint256 tokenId);
    error MarketPlace_CannotBuyYourOwnNFT();
    error MarketPlace_NFT_Transfer_Failed();
    error MarketPlace_NoTEnoughRevenue();
    error MarketPlace_NFTNotListed(address _nftAddress,uint256 _tokenId);
    error MarketPlace_ListingPriceMustBeGreaterThanZero();

    //----------------------------- types ------------------------------------------------------
     struct Listing{
        uint256 price;
        address seller;
     }

    //------------------------------ state variables -------------------------------------------
    address paymentToken;
    mapping(address => mapping(uint256 => Listing)) nftListings;
    mapping(address => uint256) userRevenue;

    //------------------------------ custom events ---------------------------------------------
    event _TokenListed(address token_address ,uint256 _tokenId, uint256 _amount);
    event _ListingUpdated(address token_address ,uint256 _tokenId, uint256 _newPrice);
    event _nftSold(address indexed _nftAddress,uint256 indexed _tokenId, uint256 indexed _amount);
    event MarketPlace_RevenueWithdrawn(address indexed _owner ,uint256 indexed _amount);
    event CancelledListing(address indexed _nftAddress,uint256 indexed _tokenId);


    //------------------------------ constructor ----------------------------------------------

     constructor(address _token){
        paymentToken = _token;
     }

    //------------------------------ modifiers -------------------------------------------------
    modifier _isOwner(address _user,address _nftAddress, uint256 _tokenId){
        if(IERC721(_nftAddress).ownerOf(_tokenId) !=_user){
            revert MarketPlace_NotOwnerOfNFT();
        }
        _;
    }

    modifier _Listed(address _nftAddress, uint256 _tokenId) {
        Listing memory listing = nftListings[_nftAddress][_tokenId] ;
        if(listing.price <= 0){
         revert MarketPlace_NFTNotListed(_nftAddress, _tokenId);
        }
        _;
    }

modifier _notListed(address _nftAddress, uint256 _tokenId) {
        Listing memory listing = nftListings[_nftAddress][_tokenId] ;
        if(listing.price >0){
         revert MarketPlace_NFTAlreadyListed(_nftAddress, _tokenId);
        }
        _;
    }

    modifier _approveMarketPlace(address _nftAddress,uint256 _tokenId){
        IERC721(_nftAddress).approve(address(this), _tokenId);
        _;
    }


    //------------------------------- public functions------------------------------------------
    /**
     *@param _nftAddress: address of the nft collection
     *@param _tokenId: unique id of the token in nft collection
     *@param _price: price of nft in USDC
     *@notice conditions to list:
       - must be owner
       - token must not be already listed
       - non-reentrant
        */
    function listNft(address _nftAddress, uint256 _tokenId, uint256 _price) public 
    _isOwner(msg.sender,_nftAddress,_tokenId)
    _notListed(_nftAddress,_tokenId)
     nonReentrant
      {
        //price must be greater than 0
        if(_price <=0){
            revert MarketPlace_ListingPriceMustBeGreaterThanZero();
        }

        //set price && owner
       nftListings[_nftAddress][_tokenId].price = _price;
       nftListings[_nftAddress][_tokenId].seller = msg.sender;
       emit _TokenListed(_nftAddress,_tokenId,_price);
    }

    /**
     * 
     * @param _nftAddress : address of nft contract  
     * @param _tokenId  : token id of the selected nft
     */
    function cancelListing(address _nftAddress,uint256 _tokenId) 
    _isOwner(msg.sender,_nftAddress,_tokenId)
    _Listed(_nftAddress,_tokenId)
    public {
        //update listing 
        delete nftListings[_nftAddress][_tokenId];
        emit CancelledListing(_nftAddress,_tokenId);

    }

    /**
     *@param _nftAddress: address of the nft collection
     *@param _tokenId: unique id of the token in nft collection
     *@param _newAmount: price of nft in USDC
     *@notice conditions to update listing :
       - must be owner
       - non-reentrant
       - token must already be listed 
     */
     function updateListing(address _nftAddress,uint256 _tokenId, uint256 _newAmount) public 
    _isOwner(msg.sender,_nftAddress,_tokenId)
    _Listed(_nftAddress,_tokenId)
     nonReentrant {
       nftListings[_nftAddress][_tokenId].price = _newAmount;
       emit _ListingUpdated(_nftAddress,_tokenId,_newAmount);
    }
    
    /**
     * @param _nftAddress: address of nft collectiont to buy from 
     * @param _tokenId : ID of the unique token to buy
     * @notice conditions to buy a listing :
       - must not be owner
       - non-reentrant
       - token must already be listed 
     */
    function buyNft(address _nftAddress, uint256 _tokenId) public 
    nonReentrant
    _Listed(_nftAddress,_tokenId)
     {
    Listing memory listedItem = nftListings[_nftAddress][_tokenId];
    //if buyer is owner revert
    if(listedItem.seller == msg.sender){
        revert MarketPlace_CannotBuyYourOwnNFT();
    }
    //delete listing mapping 
    uint256 price = listedItem.price;
    delete nftListings[_nftAddress][_tokenId];
    //transfer token amount to user 
    IERC20(paymentToken).safeTransferFrom(msg.sender, address(this), price);
    // transfer nft to msg.sender 
    IERC721(_nftAddress).transferFrom(listedItem.seller,msg.sender, _tokenId);
    //update owner_revenue
    userRevenue[listedItem.seller ] += price;
    emit _nftSold(_nftAddress, _tokenId, price);
    }

    /**
     * 
     */
    function withDrawRevenue(uint256 _amount) public nonReentrant {
      // check if owner has some revenue:
      if(userRevenue[msg.sender] <=0 || userRevenue[msg.sender] < _amount){
        revert MarketPlace_NoTEnoughRevenue();
      }
      //update revenue
      delete userRevenue[msg.sender];
      //send revenue to user;
      IERC20(paymentToken).safeTransfer(msg.sender, _amount);
      emit MarketPlace_RevenueWithdrawn(msg.sender,_amount);
    }


    //------------------------------- view, pure functions -------------------------------------
    function getPaymentToken() public view returns(address){
        return paymentToken;
    }

    function getListing(address _nftAddress, uint256 _tokenId) public view returns(Listing memory){
         return nftListings[_nftAddress][_tokenId];
    }

    function getUserRevenue(address _user )public view returns (uint256){
         return userRevenue[_user];
    }
    
}