// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title LazyMintNFT
 * @dev A contract that implements lazy minting (mint on first transfer) of NFTs
 * with advanced features and optimizations for competition standards.
 */
contract LazyMintNFT is ERC721, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    
    Counters.Counter private _tokenIdCounter;

    // Mapping from token ID to creator address
    mapping(uint256 => address) private _creators;
    
    // Mapping from token ID to whether it's been minted
    mapping(uint256 => bool) private _mintedTokens;
    
    // Mapping from hash of metadata to token ID (prevents duplicate metadata)
    mapping(bytes32 => uint256) private _metadataHashes;
    
    // Base URI for token metadata
    string private _baseTokenURI;
    
    // Royalty information
    struct RoyaltyInfo {
        address recipient;
        uint24 amount; // basis points (e.g., 1000 = 10%)
    }
    
    // Mapping from token ID to royalty info
    mapping(uint256 => RoyaltyInfo) private _royalties;

    // Events
    event TokenPrepared(uint256 indexed tokenId, address indexed creator, string tokenURI);
    event TokenMinted(uint256 indexed tokenId, address indexed owner);
    event RoyaltySet(uint256 indexed tokenId, address recipient, uint256 amount);

    /**
     * @dev Constructor that sets the base URI for token metadata
     * @param name_ Name of the NFT collection
     * @param symbol_ Symbol of the NFT collection
     * @param baseTokenURI_ Base URI for token metadata
     */
    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseTokenURI_
    ) ERC721(name_, symbol_) Ownable(msg.sender) {
        _baseTokenURI = baseTokenURI_;
    }

    /**
     * @dev Prepares a token for lazy minting (doesn't actually mint)
     * @param to The address that will own the token when minted
     * @param tokenURI The URI for the token metadata
     * @return tokenId The ID of the prepared token
     */
    function prepareToken(address to, string memory tokenURI) external returns (uint256) {
        require(bytes(tokenURI).length > 0, "LazyMintNFT: tokenURI cannot be empty");
        
        // Generate a hash of the metadata to prevent duplicates
        bytes32 metadataHash = keccak256(abi.encodePacked(tokenURI));
        require(_metadataHashes[metadataHash] == 0, "LazyMintNFT: duplicate metadata");
        
        // Increment token counter and get new ID
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();
        
        // Store creator information
        _creators[tokenId] = msg.sender;
        
        // Store metadata hash to prevent duplicates
        _metadataHashes[metadataHash] = tokenId;
        
        // Set token URI (will be used when minted)
        _setTokenURI(tokenId, tokenURI);
        
        emit TokenPrepared(tokenId, msg.sender, tokenURI);
        
        return tokenId;
    }

    /**
     * @dev Sets royalty information for a token
     * @param tokenId The token ID
     * @param recipient Address to receive royalties
     * @param amount Royalty amount in basis points (e.g., 1000 = 10%)
     */
    function setRoyalty(uint256 tokenId, address recipient, uint24 amount) external {
        require(_creators[tokenId] == msg.sender, "LazyMintNFT: only creator can set royalty");
        require(amount <= 10000, "LazyMintNFT: royalty amount too high");
        
        _royalties[tokenId] = RoyaltyInfo(recipient, amount);
        emit RoyaltySet(tokenId, recipient, amount);
    }

    /**
     * @dev Transfers a token (mints if not already minted)
     * @param from The current owner of the token
     * @param to The address to receive the token
     * @param tokenId The token ID to transfer
     */
    function _transfer(address from, address to, uint256 tokenId) internal override {
        // Mint the token if it hasn't been minted yet
        if (!_mintedTokens[tokenId]) {
            _mintToken(tokenId, from);
        }
        
        super._transfer(from, to, tokenId);
    }

    /**
     * @dev Internal function to mint a token
     * @param tokenId The token ID to mint
     * @param owner The owner of the minted token
     */
    function _mintToken(uint256 tokenId, address owner) private {
        require(!_mintedTokens[tokenId], "LazyMintNFT: token already minted");
        require(_exists(tokenId), "LazyMintNFT: token does not exist");
        
        _mintedTokens[tokenId] = true;
        _safeMint(owner, tokenId);
        
        emit TokenMinted(tokenId, owner);
    }

    /**
     * @dev Returns whether a token has been minted
     * @param tokenId The token ID to check
     * @return bool Whether the token has been minted
     */
    function isMinted(uint256 tokenId) external view returns (bool) {
        return _mintedTokens[tokenId];
    }

    /**
     * @dev Returns the creator of a token
     * @param tokenId The token ID
     * @return address The creator's address
     */
    function creatorOf(uint256 tokenId) external view returns (address) {
        return _creators[tokenId];
    }

    /**
     * @dev Returns royalty information for a token
     * @param tokenId The token ID
     * @param salePrice The sale price of the token
     * @return receiver The address to receive royalties
     * @return royaltyAmount The royalty amount
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view returns (address receiver, uint256 royaltyAmount) {
        RoyaltyInfo memory royalty = _royalties[tokenId];
        if (royalty.recipient == address(0)) {
            return (address(0), 0);
        }
        royaltyAmount = (salePrice * royalty.amount) / 10000;
        return (royalty.recipient, royaltyAmount);
    }

    /**
     * @dev Returns the base URI for token metadata
     * @return string The base URI
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @dev Updates the base URI for token metadata
     * @param baseTokenURI The new base URI
     */
    function setBaseURI(string memory baseTokenURI) external onlyOwner {
        _baseTokenURI = baseTokenURI;
    }

    /**
     * @dev Returns the token URI for a given token ID
     * @param tokenId The token ID
     * @return string The token URI
     */
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    /**
     * @dev Returns whether a token exists
     * @param tokenId The token ID to check
     * @return bool Whether the token exists
     */
    function _exists(uint256 tokenId) internal view override returns (bool) {
        return tokenId > 0 && tokenId <= _tokenIdCounter.current();
    }

    /**
     * @dev Returns the current token ID counter
     * @return uint256 The current token ID
     */
    function currentTokenId() external view returns (uint256) {
        return _tokenIdCounter.current();
    }

    /**
     * @dev Returns the interface support
     * @param interfaceId The interface ID to check
     * @return bool Whether the interface is supported
     */
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return 
            interfaceId == 0x2a55205a || // ERC2981 interface ID for royalties
            super.supportsInterface(interfaceId);
    }
}
