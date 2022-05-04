pragma solidity 0.6.12;

import "./lib-erc/IERC721Base.sol";

import './lib/SafeMath.sol';
import './lib/IBEP20.sol';
import './lib/SafeBEP20.sol';
import './lib/Ownable.sol';
import "./lib/ReentrancyGuard.sol";

import "./TheNFTCryptoGirl.sol";

contract TheNftMarketplaceV2 is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    // CryptoGirlNFT
    TheNFTCryptoGirl public TheNFTCG;

    // Lp Token
    IBEP20 public lpToken;

    // Fee address
    address public feeAddress;

    // Map from token ID to their corresponding auction.
    mapping (address => mapping (uint256 => Auction)) public auctions;

    struct Auction {
        address seller;
        uint256 price;
        uint64 duration;
        uint64 startedAt;
    }

    uint256 public ownerCut = 1000;

    event SetFeeAddress(address indexed user, address indexed _feeAddress);

    event AuctionCreated(
        address indexed _nftAddress,
        uint256 indexed _tokenId,
        uint256 price,
        uint256 _duration,
        address _seller
    );

    event AuctionSuccessful(
        address indexed _nftAddress,
        uint256 indexed _tokenId,
        uint256 _totalPrice,
        address _winner
    );

    event AuctionCancelled(
        address indexed _nftAddress,
        uint256 indexed _tokenId
    );

    event GetTokens(address indexed masterchef, IBEP20 _token, uint256 amount);

    constructor(
        IBEP20 _lpToken,
        address _feeAddress,
        TheNFTCryptoGirl _TheNFTCG
    ) public {
        lpToken = _lpToken;
        feeAddress = _feeAddress;
        TheNFTCG = _TheNFTCG;
    }

    function setFeeAddress(address _feeAddress) public {
        require(_feeAddress != address(0), "setFeeAddress: invalid address");
        require(msg.sender == feeAddress, "setFeeAddress: FORBIDDEN");
        feeAddress = _feeAddress;
        emit SetFeeAddress(msg.sender, _feeAddress);
    }

    function setOwnerCut(uint256 _ownerCut) public onlyOwner {
        require(_ownerCut <= 1000);
        ownerCut = _ownerCut;
    }

    function getAuction(
        address _nftAddress,
        uint256 _tokenId
    )
    external
    view
    returns (
        address seller,
        uint256 price,
        uint256 duration,
        uint256 startedAt
    )
    {
        Auction storage _auction = auctions[_nftAddress][_tokenId];
        require(_isOnAuction(_auction));
        return (
            _auction.seller,
            _auction.price,
            _auction.duration,
            _auction.startedAt
        );
    }

    function _addAuction(
        address _nftAddress,
        uint256 _tokenId,
        Auction memory _auction,
        address _seller
    )
    internal
    {
        require(_auction.duration >= 1 minutes);

        auctions[_nftAddress][_tokenId] = _auction;

        AuctionCreated(
            _nftAddress,
            _tokenId,
            uint256(_auction.price),
            uint256(_auction.duration),
            _seller
        );
    }

    function createAuction(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _price,
        uint256 _duration
    )
    external
    canBeStoredWith128Bits(_price)
    canBeStoredWith64Bits(_duration)
    {
        address _seller = msg.sender;
        require(_owns(_nftAddress, _seller, _tokenId));
        _escrow(_nftAddress, _seller, _tokenId);
        Auction memory _auction = Auction(
            address(_seller),
            uint128(_price),
            uint64(_duration),
            uint64(now)
        );
        _addAuction(
            _nftAddress,
            _tokenId,
            _auction,
            _seller
        );
    }

    function bid(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _bidAmount
    )
    public
    {
        Auction storage _auction = auctions[_nftAddress][_tokenId];

        require(_isOnAuction(_auction));

        uint256 _price = _auction.price;
        require(_bidAmount >= _price);

        address _seller = _auction.seller;

        _removeAuction(_nftAddress, _tokenId);

        if (_price > 0) {
            uint256 _auctioneerCut = _computeCut(_bidAmount);
            uint256 _sellerProceeds = _bidAmount - _auctioneerCut;

            lpToken.safeTransferFrom(address(msg.sender), address(this), _bidAmount);
            lpToken.safeTransfer(address(_seller), _sellerProceeds);
            lpToken.safeTransfer(address(feeAddress), _auctioneerCut);
        }

        AuctionSuccessful(
            _nftAddress,
            _tokenId,
            _price,
            msg.sender
        );


        _transfer(_nftAddress, msg.sender, _tokenId);
    }

    function cancelAuction(address _nftAddress, uint256 _tokenId) external {
        Auction storage _auction = auctions[_nftAddress][_tokenId];
        require(_isOnAuction(_auction));
        require(msg.sender == _auction.seller);
        _cancelAuction(_nftAddress, _tokenId, _auction.seller);
    }

    function tokensOfSeller(address nftAddress, address _seller) external view returns(uint256[] memory ownerTokens) {
        uint256[] memory nftsMarketplace = TheNFTCG.tokensOfOwner(address(this));
        uint256 totalCount = nftsMarketplace.length;

        if (totalCount == 0) {
            return new uint256[](0);
        } else {

            uint256 tokensOfSeller = 0;
            uint256 i;

            for (i = 0; i < totalCount; i++) {
                uint256 tokenId = nftsMarketplace[i];
                if (auctions[nftAddress][tokenId].seller == _seller) {
                    tokensOfSeller++;
                }
            }

            uint256[] memory result = new uint256[](tokensOfSeller);
            uint256 resultIndex = 0;

            for (i = 0; i < totalCount; i++) {
                uint256 tokenId = nftsMarketplace[i];
                if (auctions[nftAddress][tokenId].seller == _seller) {
                    result[resultIndex] = tokenId;
                    resultIndex++;
                }
            }

            return result;
        }
    }

    function transferTokensToAdmin(IBEP20 _token, uint256 _amount) public onlyOwner nonReentrant {
        _token.safeTransfer(feeAddress, _amount);

        emit GetTokens(feeAddress, _token, _amount);
    }

    function _cancelAuction(address _nftAddress, uint256 _tokenId, address _seller) internal {
        _removeAuction(_nftAddress, _tokenId);
        _transfer(_nftAddress, _seller, _tokenId);
        AuctionCancelled(_nftAddress, _tokenId);
    }

    function _transfer(address _nftAddress, address _receiver, uint256 _tokenId) internal {
        IERC721Base _nftContract = _getNftContract(_nftAddress);
        _nftContract.transferFrom(address(this), address(_receiver), _tokenId);
    }

    function _removeAuction(address _nftAddress, uint256 _tokenId) internal {
        delete auctions[_nftAddress][_tokenId];
    }

    function _owns(address _nftAddress, address _claimant, uint256 _tokenId) internal view returns (bool) {
        IERC721Base _nftContract = _getNftContract(_nftAddress);
        return (_nftContract.ownerOf(_tokenId) == _claimant);
    }

    function _escrow(address _nftAddress, address _owner, uint256 _tokenId) internal {
        IERC721Base _nftContract = _getNftContract(_nftAddress);

        // It will throw if transfer fails
        _nftContract.transferFrom(address(_owner), address(this), _tokenId);
    }

    function _getNftContract(address _nftAddress) internal pure returns (IERC721Base) {
        IERC721Base candidateContract = IERC721Base(_nftAddress);
        // require(candidateContract.implementsERC721());
        return candidateContract;
    }

    function _isOnAuction(Auction storage _auction) internal view returns (bool) {
        return (_auction.startedAt > 0);
    }

    function _computeCut(uint256 _price) internal view returns (uint256) {
        return _price * ownerCut / 10000;
    }

    modifier canBeStoredWith64Bits(uint256 _value) {
        require(_value <= 18446744073709551615);
        _;
    }

    modifier canBeStoredWith128Bits(uint256 _value) {
        require(_value < 340282366920938463463374607431768211455);
        _;
    }
}