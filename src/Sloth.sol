// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

/// @title OnChainSloth
/// @notice Minimal on-chain generative Sloth ERC721: stores a deterministic seed per token and
///         generates an SVG-based image and metadata on-chain.
/// @dev All functions documented with NatSpec.
contract Sloth is ERC721, Ownable {
    using Strings for uint256;

    uint256 private _tokenIds;
    mapping(uint256 _tokenId => uint256 seed) private _seeds;

    /// @notice Emitted when a new Sloth is minted.
    /// @param tokenId token identifier
    /// @param to recipient address
    /// @param seed deterministic seed used to generate the Sloth traits
    event SlothMinted(uint256 indexed tokenId, address indexed to, uint256 seed);

    /// @notice Initialize the ERC721 collection.
    /// @dev Sets the token name and symbol.
    constructor() ERC721("OnChainSloth", "SLOTH") Ownable(msg.sender){}

    /// @notice Mint a new Sloth NFT to the caller (owner only).
    /// @dev The owner of the contract mints; the provided seed is stored and is used to derive traits.
    /// @return tokenId The newly minted token id.
    function mintSloth()external onlyOwner returns (uint256) {
        uint256 seed = _tokenIds;
        _safeMint(msg.sender, _tokenIds);
        _seeds[_tokenIds] = seed;
        _tokenIds += 1;
        emit SlothMinted(_tokenIds, msg.sender, seed);
        return _tokenIds;
    }

    /// @notice Build the SVG string for a given token id from its stored seed.
    /// @dev Internal helper that composes SVG fragments based on the seed. Reverts if token does not exist.
    /// @param tokenId Token identifier for which to build the SVG.
    /// @return svg The full SVG XML string for the token image.
    function _buildSVG(uint256 tokenId) internal view returns (string memory svg) {
        require(_tokenExists(tokenId), "SVG query for nonexistent token");

        uint256 randomness = _seeds[tokenId];
        // Derive trait indices from the seed
        string memory bodyColor = _pickColor(randomness % 5);
        string memory eyeType = _pickEye((randomness >> 1) % 3);
        string memory hat = _pickHat((randomness >> 2) % 3);

        string memory hair = _pickHair((randomness >> 3) % 3);
        string memory mustache = _pickMustache((randomness >> 4) % 2);

        svg = string(
            abi.encodePacked(
                "<svg xmlns='http://www.w3.org/2000/svg' width='400' height='400'>",
                    "<rect width='100%' height='100%' fill='", bodyColor, "'/>",
                    "<circle cx='200' cy='200' r='100' fill='beige'/>",
                    eyeType,
                    hat,
                    hair,
                    mustache,
                "</svg>"
            )
        );
    }

    /// @notice Return tokenURI as a base64-encoded JSON data URI containing the image (SVG).
    /// @dev Composes metadata JSON on-chain and base64-encodes it. Reverts if token does not exist.
    /// @param tokenId Token identifier for which to return metadata.
    /// @return A data:application/json;base64,... token URI string.
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_tokenExists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory svg = _buildSVG(tokenId);

        // Encode image as base64 data URI
        string memory image = string(
            abi.encodePacked(
                "data:image/svg+xml;base64,",
                Base64.encode(bytes(svg))
            )
        );

        // Compose metadata JSON
        string memory json = string(
            abi.encodePacked(
                '{"name":"Sloth #', tokenId.toString(),
                '","description":"On-chain generative Sloth NFT.",',
                '"image":"', image, '"}'
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    // ------------------- TRAIT HELPERS -------------------

    /// @notice Pick a background/body color by index.
    /// @dev Index is assumed to be in range [0,4].
    /// @param id Index of color.
    /// @return Color hex string.
    function _pickColor(uint256 id) internal pure returns (string memory) {
        string[5] memory colors = ["#a3d9a5", "#f9c74f", "#90be6d", "#577590", "#f9844a"];
        return colors[id];
    }

    /// @notice Return SVG fragment for eyes by index.
    /// @param id Eye style index.
    /// @return svgFragment SVG markup fragment for eyes.
    function _pickEye(uint256 id) internal pure returns (string memory svgFragment) {
        if (id == 0) return "<circle cx='170' cy='190' r='10' fill='black'/><circle cx='230' cy='190' r='10' fill='black'/>";
        if (id == 1) return "<rect x='160' y='180' width='20' height='10' fill='black'/><rect x='220' y='180' width='20' height='10' fill='black'/>";
        return "<ellipse cx='170' cy='190' rx='12' ry='8' fill='black'/><ellipse cx='230' cy='190' rx='12' ry='8' fill='black'/>";
    }

    /// @notice Return SVG fragment for hat by index.
    /// @param id Hat style index.
    /// @return svgFragment SVG markup fragment for hat.
    function _pickHat(uint256 id) internal pure returns (string memory svgFragment) {
        if (id == 0) return "";
        if (id == 1) return "<rect x='150' y='110' width='100' height='30' fill='black'/><rect x='170' y='70' width='60' height='40' fill='black'/>";
        return "<polygon points='200,50 170,110 230,110' fill='red'/>";
    }

    /// @notice Return SVG fragment for hair by index.
    /// @param id Hair style index.
    /// @return svgFragment SVG markup fragment for hair.
    function _pickHair(uint256 id) internal pure returns (string memory svgFragment) {
        if (id == 0) return "";
        if (id == 1) return "<path d='M140 150 Q200 80 260 150' stroke='brown' stroke-width='8' fill='none'/>";
        return "<path d='M150 150 Q200 50 250 150' stroke='black' stroke-width='6' fill='none'/>";
    }

    /// @notice Return SVG fragment for mustache by index.
    /// @param id Mustache index (0 = none, 1 = present).
    /// @return svgFragment SVG markup fragment for mustache.
    function _pickMustache(uint256 id) internal pure returns (string memory svgFragment) {
        if (id == 0) return "";
        return "<path d='M170 220 Q200 240 230 220' stroke='black' stroke-width='4' fill='none'/>";
    }

    /// @dev Internal helper to determine whether a token exists without relying on an internal _exists symbol.
    ///      ownerOf is called via an external call and caught if it reverts for nonexistent tokens.
    function _tokenExists(uint256 tokenId) internal view returns (bool) {
        try this.ownerOf(tokenId) returns (address) {
            return true;
        } catch {
            return false;
        }
    }

     /// @notice Return the seed stored for a given token id.
    /// @dev Reverts if token does not exist.
    /// @param tokenId Token identifier.
    /// @return seed Stored seed used to generate the token's traits.
    function getSeed(uint256 tokenId) external view returns (uint256 seed) {
        require(_tokenExists(tokenId), "Seed query for nonexistent token");
        return _seeds[tokenId];
    }
}