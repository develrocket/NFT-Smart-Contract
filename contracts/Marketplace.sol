// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./MamonNFT.sol";


contract ERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {}
    function approve(address spender, uint256 amount) public returns (bool) {}
    function transfer(address recipient, uint256 amount) public returns (bool) {}
    function allowance(address owner, address spender) public view returns (uint256) {}
}

contract Marketplace is AccessControl {

    int maxQuantity = 1;

    struct NFTProd {
        address owner;
        uint256 tokenID;
        uint256 price;
        string paymentMethod;
        uint8 flag;
    }
    
    bytes32 public constant PRODUCE_ROLE = keccak256("PRODUCE_ROLE");
    
    mapping (string => NFTProd) public nftProds;
    mapping (uint256 => NFTProd) public nftSellProds;
    mapping (address => uint256[]) public allowedNFT;
    string [] hashes;
    
    uint256 [] public sellList;
    
    MamonNFT mamonNFT;
    ERC20 fast;
    ERC20 duke;
    
    event Transfer(address indexed from, address indexed to, uint256 tokenID);
    event Buy(address indexed from, address indexed to, uint256 tokenID, uint256 price, string paymentMethod);
    event RegisterForSale(address indexed from, uint256 tokenID, uint256 price);
    
    constructor(MamonNFT _mamonNFT, address _fast, address _duke) {
        mamonNFT = _mamonNFT;
        fast = ERC20(address(_fast));
        fast = ERC20(address(_duke));
        _setupRole(PRODUCE_ROLE, _msgSender());
    }
    
    
    function setMaxQuantity(int _quantity) public {
        maxQuantity = _quantity;
    }
    
    function getMaxQuantity() public view returns(int) {
        return maxQuantity;
    }
    
    function createNewProduction(string memory _hash, uint256 _quantity) public returns (uint256[] memory) {
        require(hasRole(PRODUCE_ROLE, _msgSender()), "Must have produce role to mint");
        require(nftProds[_hash].flag != 1);
        uint256[] memory tokenIDs = new uint256[](_quantity);
        for(uint256 index = 0; index < _quantity; ++index) {
	        uint256 _tokenID = mamonNFT.mint(msg.sender, _hash);
	        tokenIDs[index] = _tokenID;
	    }
        
        return tokenIDs;
    }
    
    function registerForSale(uint256 _tokenID, uint256 _price, string memory _hash, string memory _paymentMethod) public {

        require((mamonNFT.getApproved(_tokenID) == address(this)), "This NFT is not approved for sale");
        require(_price > 0, "The price should be more than 0.");
        nftSellProds[_tokenID] = NFTProd(msg.sender, _tokenID, _price, _paymentMethod, 1);
        sellList.push(_tokenID);
        allowedNFT[msg.sender].push(_tokenID);
        hashes.push(_hash);
        
        emit RegisterForSale(msg.sender, _tokenID, _price);
    }
    
    function getProdList() public view returns(string[] memory){
        return hashes;
    }
    
    function getProdByHash(string memory _hash) public view returns(NFTProd memory){
        return nftProds[_hash];
    }
    
    function getNFTProdByTokenID(uint256 _tokenId) public view returns(NFTProd memory){
        return nftSellProds[_tokenId];
    }
    
    function getNFTList() public view returns(uint256[] memory){
        return sellList;
    }
    
    function getIndexOfNFT(uint256 _tokenID) public view returns(uint){
        uint arrIndex = 0;
        for(uint256 index = 0; index < sellList.length; index++) {
	        if(sellList[index] == _tokenID){
	            arrIndex = index;
	            break;
	        }
	    }
	    return arrIndex;
    }
    
    function removeItemFromSale(uint256 _tokenID) internal  {
        uint index = getIndexOfNFT(_tokenID);
        require(index < sellList.length);
        sellList[index] = sellList[sellList.length-1];
        sellList.pop();
    }
    
    function getIndexOfUserAllowedNFT(address _guy, uint256 _tokenID) public view returns(uint){
        uint arrIndex = 0;
        for(uint256 index = 0; index < allowedNFT[_guy].length; index++) {
	        if(allowedNFT[_guy][index] == _tokenID){
	            arrIndex = index;
	            break;
	        }
	    }
	    return arrIndex;
    }
    
    function removeItemFromAllowed(address _guy, uint256 _tokenID) internal {
        uint index = getIndexOfUserAllowedNFT(_guy, _tokenID);
        require(index < allowedNFT[_guy].length);
        allowedNFT[_guy][index] = allowedNFT[_guy][sellList.length-1];
        allowedNFT[_guy].pop();
    }
    
    function buy(uint256 _tokenID, uint256 _amount ) public payable returns (uint256) {
        // require(nftProds[_hash].quantity >= 1, "Must have quantity more than 1");
        require(_amount == nftSellProds[_tokenID].price, "Amount should be same with price");
        // require(fast.transferFrom(msg.sender, address(0x1), _amount), "ERC20: transfer amount exceeds allowance");
        NFTProd memory sellNFT = nftSellProds[_tokenID];
        if(keccak256(abi.encodePacked("BNB")) == keccak256(abi.encodePacked(sellNFT.paymentMethod))){
            fast.transferFrom(msg.sender, sellNFT.owner, _amount);
        } else if(keccak256(abi.encodePacked("FAST")) == keccak256(abi.encodePacked(sellNFT.paymentMethod))){
            fast.transferFrom(msg.sender, sellNFT.owner, _amount);
        } else if(keccak256(abi.encodePacked("DUKE")) == keccak256(abi.encodePacked(sellNFT.paymentMethod))){
            duke.transferFrom(msg.sender, sellNFT.owner, _amount);
        }
        mamonNFT.transferFrom(sellNFT.owner, msg.sender, _tokenID);
        removeItemFromSale(_tokenID);
        removeItemFromAllowed(msg.sender,  _tokenID);
        
        emit Transfer(sellNFT.owner, msg.sender, _tokenID);
        emit Buy(sellNFT.owner, msg.sender, _tokenID, _amount, sellNFT.paymentMethod);
        
        return _tokenID;
    }
    
}
