//SPDX-License-Identifier:MIT
pragma solidity^0.8.24;
import {Test} from 'forge-std/Test.sol';
import {Sloth} from '../src/Sloth.sol';
import {DeployMarketPlace} from '../script/DeployMarketPlace.s.sol';
import {Collection} from '../src/Collection.sol';
import {CollectionFactory} from '../src/CollectionFactory.sol';
import {MarketPlace} from '../src/MarketPlace.sol';
import {MockUSDC} from '../src/MockUSDC.sol';



contract TestMarketPlace is Test {
MarketPlace mkPlace;
CollectionFactory colFactory;
Sloth sloth;
Collection collection;
MockUSDC paymentToken;


//state variables 
string  constant COLLECTION_NAME ='Solo King';
string  constant SYMBOL ='SK';
uint256  TOTAL_SUPPLY=493;
address TOKEN_OWNER = makeAddr("token-owner");
address USER1 =makeAddr("user1");
address USER2 =makeAddr("user2");
string constant TOKEN_URI1="ipfs://someuri-one";
string constant TOKEN_URI2="ipfs://some-token-uri-2";
string constant TOKEN_URI3="ipfs://sometoke-uri-3";
string[] token_uris = [TOKEN_URI1,TOKEN_URI2,TOKEN_URI3];

function setUp() public {
    vm.deal(TOKEN_OWNER,30 ether);

    vm.startPrank(TOKEN_OWNER);
    //deployMock payment token
    paymentToken = new MockUSDC();
    // mint user some payment tokens
    paymentToken.mint(USER1,2002);
    paymentToken.mint(USER2,2303);
    vm.stopPrank();

    string memory COLLECTION_URI ='ipfs://cloud.io/30020404ee030d.json';
    (mkPlace, colFactory) = new DeployMarketPlace().run();
    //get col
    vm.startPrank(USER1);
    collection = Collection(colFactory.createCollection(COLLECTION_NAME,SYMBOL,TOTAL_SUPPLY,COLLECTION_URI));
    //mint some collection nfts 
    for(uint128 i=0; i < token_uris.length ; i++){
        collection.mint(token_uris[i]);
    }
    vm.stopPrank();
}


//Test markeptplace is granted permission to transfer collection on listing
function test_MarketPlaceGetsApprovalToTransferCollection() public {
    vm.startPrank(USER1);
    //user musk first approve marketplace
    collection.approve(address(mkPlace),1);
    collection.approve(address(mkPlace),2);
    collection.approve(address(mkPlace),3);
     //lsit NFTS on the marketplace
     mkPlace.listNft(address(collection),1,405);
     mkPlace.listNft(address(collection),2,4030);
     mkPlace.listNft(address(collection),3,950);
     vm.stopPrank();
     //verify that marketplace is approved to list
     assertEq(collection.getApproved(1), address(mkPlace), 'Approval not successful');
     assertEq(collection.getApproved(2), address(mkPlace), 'Approval not successful');
     assertEq(collection.getApproved(3), address(mkPlace), 'Approval not successful');

}
  // test buying on the marketplace
    function test_buyNftTransfersOwnershipAndFunds() public {
        uint256 price = 1_000;
        // USER1 approves & lists tokenId 1
        vm.prank(USER1);
        collection.approve(address(mkPlace), 1);
        vm.prank(USER1);
        mkPlace.listNft(address(collection), 1, price);

        // obtain the payment token used by the marketplace and mint funds to buyer (TOKEN_OWNER)
        MockUSDC mpToken = MockUSDC(mkPlace.getPaymentToken());
        address token_owner = mpToken.owner();

        // mint the exact tokens that marketplace uses to user 2
        vm.prank(token_owner);
        mpToken.mint(USER2, 2_000);

        // simulate buy by user2
        vm.prank(USER2);
        mpToken.approve(address(mkPlace), price);

        // buyer approves marketplace and buys
        vm.prank(USER2);
        mkPlace.buyNft(address(collection), 1);

        // ownership transferred to buyer
        assertEq(collection.ownerOf(1), USER2, "Ownership not transferred to buyer");
        // buyer balance decreased and marketplace contract received funds
        assertEq(mpToken.balanceOf(USER2), 2000 - price, "Buyer balance incorrect after purchase");
        assertEq(mpToken.balanceOf(address(mkPlace)), price, "Marketplace did not receive payment");
    }


 // test listing on the marketplace (getListing returns correct data)
    function test_listingOnMarketplaceStoresListing() public {
        uint256 price = 405;
        vm.prank(USER1);
        collection.approve(address(mkPlace), 2);

        vm.prank(USER1);
        mkPlace.listNft(address(collection), 2, price);

        MarketPlace.Listing memory listing = mkPlace.getListing(address(collection), 2);
        
        assertEq(listing.price, price, "Stored price mismatch");
        assertEq(listing.seller, USER1, "Stored seller mismatch");
    }


  // test unlisting on the marketplace
    function test_unlistingRemovesListing() public {
        uint256 price = 950;

        vm.prank(USER1);
        collection.approve(address(mkPlace), 3);

        vm.prank(USER1);
        mkPlace.listNft(address(collection), 3, price);

        // cancel listing
        vm.prank(USER1);
        mkPlace.cancelListing(address(collection), 3);

        MarketPlace.Listing memory listing = mkPlace.getListing(address(collection), 3);
        assertEq(listing.price, 0, "Listing price should be zero after cancel");
        assertEq(listing.seller, address(0), "Listing seller should be zero address after cancel");
    }

    // test tokenURI matches the URI provided at mint
    function test_tokenURIMatchesMintedURI() public {
        string memory uri = collection.tokenURI(1);
        assertEq(uri, TOKEN_URI1, "tokenURI does not match minted URI");
    }

    /// @notice Seller can update an existing listing price; new price is persisted
    function test_updateListingChangesPrice() public {
        uint256 originalPrice = 500;
        uint256 newPrice = 900;

        // USER1 approves and lists token 2
        vm.prank(USER1);
        collection.approve(address(mkPlace), 2);
        vm.prank(USER1);
        mkPlace.listNft(address(collection), 2, originalPrice);

        // USER1 updates the listing to a new price
        vm.prank(USER1);
        mkPlace.updateListing(address(collection), 2, newPrice);

        MarketPlace.Listing memory listing = mkPlace.getListing(address(collection), 2);
        assertEq(listing.price, newPrice, "Listing price not updated");
        assertEq(listing.seller, USER1, "Seller should remain unchanged after update");
    }

    /// @notice After a successful purchase, the seller's revenue is tracked and can be withdrawn
    function test_buyNftCreditsSellerRevenueAndAllowsWithdraw() public {
        uint256 price = 1_200;

        // USER1 approves & lists tokenId 1 on the marketplace
        vm.prank(USER1);
        collection.approve(address(mkPlace), 1);
        vm.prank(USER1);
        mkPlace.listNft(address(collection), 1, price);

        // Use the marketplace's payment token instance
        MockUSDC mpToken = MockUSDC(address(mkPlace.getPaymentToken()));
        address tokenOwner = mpToken.owner();

        // Mint marketplace token to USER2 (buyer)
        vm.prank(tokenOwner);
        mpToken.mint(USER2, price + 500);

        // Buyer approves marketplace and buys
        vm.prank(USER2);
        mpToken.approve(address(mkPlace), price);
    
        vm.prank(USER2);
        mkPlace.buyNft(address(collection), 1);

        // After purchase, the marketplace should have recorded seller revenue
        uint256 sellerRevenue = mkPlace.getUserRevenue(USER1);
        assertEq(sellerRevenue, price, "Seller revenue not recorded correctly");

        // Seller withdraws revenue
        uint256 sellerBalanceBefore = mpToken.balanceOf(USER1);
        vm.prank(USER1);
        mkPlace.withDrawRevenue(price);
        uint256 sellerBalanceAfter = mpToken.balanceOf(USER1);
        assertEq(sellerBalanceAfter - sellerBalanceBefore, price, "Withdraw did not transfer correct amount");

        // Marketplace balance should be zero (or decreased by price)
        assertEq(mpToken.balanceOf(address(mkPlace)), 0, "Marketplace should not hold the withdrawn funds");
    }

    /// @notice Non-owner cannot list an NFT; operation should revert with the NotOwner error
    function test_listNftRevertsIfNotOwner() public {
        uint256 price = 777;

        // USER2 (not owner of token 1) tries to list -> expect revert
        // craft error selector for MarketPlace_NotOwnerOfNFT()
        bytes memory selector = abi.encodeWithSelector(bytes4(keccak256("MarketPlace_NotOwnerOfNFT()")));
        vm.expectRevert(selector);
        vm.prank(USER2);
        mkPlace.listNft(address(collection), 1, price);
    }

    
    //----------- revert if buyer's balance is not enough
    function test_buyRevertsWhenBuyerHasInsufficientBalance() public {
        uint256 price = 5_000;

        // seller (USER1) approves & lists token 1
        vm.prank(USER1);
        collection.approve(address(mkPlace), 1);
        vm.prank(USER1);
        mkPlace.listNft(address(collection), 1, price);

        // use marketplace's payment token instance and mint insufficient funds to USER2
        MockUSDC mpToken = MockUSDC(address(mkPlace.getPaymentToken()));
        address mpTokenOwner = mpToken.owner();
        // give USER2 less than price
        vm.prank(mpTokenOwner);
        mpToken.mint(USER2, 1_000);

        // buyer approves the marketplace for the small balance
        vm.prank(USER2);
        mpToken.approve(address(mkPlace), 1_000);

        // expect revert due to insufficient token balance when marketplace pulls funds
        vm.prank(USER2);
        vm.expectRevert(); // generic revert (ERC20 transfer will revert)
        mkPlace.buyNft(address(collection), 1);
    }

    /// ------------ revert if item is not listed
    function test_buyRevertsIfItemNotListed() public {
        // ensure token 2 is not listed
        // compute selector for MarketPlace_NFTNotListed(address,uint256)
        bytes4 sel = bytes4(keccak256("MarketPlace_NFTNotListed(address,uint256)"));
        vm.expectRevert(abi.encodeWithSelector(sel, address(collection), uint256(2)));
        // attempt to buy unlisted token 2
        vm.prank(USER2);
        mkPlace.buyNft(address(collection), 2);
    }

    // ------------revert if a non-owner tries to unlist an nft
    function test_cancelListingRevertsIfNotOwner() public {
        uint256 price = 777;

        // USER1 lists token 3
        vm.prank(USER1);
        collection.approve(address(mkPlace), 3);
        vm.prank(USER1);
        mkPlace.listNft(address(collection), 3, price);

        // non-owner USER2 attempts to cancel -> expect MarketPlace_NotOwnerOfNFT()
        bytes4 sel = bytes4(keccak256("MarketPlace_NotOwnerOfNFT()"));
        vm.expectRevert(sel);
        vm.prank(USER2);
        mkPlace.cancelListing(address(collection), 3);
    }

    /// ----------- withdrawal by a seller after successful sale
    function test_sellerCanWithdrawRevenueAfterSale() public {
        uint256 price = 1_200;

        // USER1 approves & lists token 1
        vm.prank(USER1);
        collection.approve(address(mkPlace), 1);
        vm.prank(USER1);
        mkPlace.listNft(address(collection), 1, price);

        // marketplace payment token and mint funds to buyer USER2
        MockUSDC mpToken = MockUSDC(address(mkPlace.getPaymentToken()));
        address mpTokenOwner = mpToken.owner();
        vm.prank(mpTokenOwner);
        mpToken.mint(USER2, price + 500);

        // buyer approves and buys
        vm.prank(USER2);
        mpToken.approve(address(mkPlace), price);
        vm.prank(USER2);
        mkPlace.buyNft(address(collection), 1);

        // seller's revenue should equal price
        uint256 revenue = mkPlace.getUserRevenue(USER1);
        assertEq(revenue, price, "Seller revenue mismatch after sale");

        // seller withdraws revenue
        uint256 before = mpToken.balanceOf(USER1);
        vm.prank(USER1);
        mkPlace.withDrawRevenue(price);
        uint256 a_fter = mpToken.balanceOf(USER1);
        assertEq(a_fter - before, price, "Withdraw did not transfer expected amount");
    }

    // ------------------------------------ Stateless fuzzing -------------------------------


    
}
