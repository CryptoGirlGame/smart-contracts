pragma solidity 0.6.12;

import './lib/SafeMath.sol';
import './lib/IBEP20.sol';
import './lib/SafeBEP20.sol';
import './lib/Ownable.sol';
import './lib/ReentrancyGuard.sol';

import './TheNFTCryptoGirl.sol';

contract TheNFTBuyCards is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    event BuyHeroCard(address indexed sender, uint256 indexed cardsPaymentsTypePid, uint256 tokenID);

    struct CardsPaymentsTypes {
        IBEP20 token;
        uint256 tokenQty;
        uint256 heroType;
        bool isActive;
    }

    CardsPaymentsTypes[] public cardsPaymentsTypes;

    TheNFTCryptoGirl public nftMasterAddress;

    bool public thisContractIsActive = true;

    modifier onlyIfIsActive() {
        require(thisContractIsActive, "You can use, if is active");
        _;
    }

    function setContractState(bool _newContractState) public onlyOwner {
        thisContractIsActive = _newContractState;
    }

    function changeNFTMasterAddress(TheNFTCryptoGirl _address) public onlyOwner {
        nftMasterAddress = _address;
    }

    function addCardsPaymentsTypes(IBEP20 _token, uint256 _tokenQty, uint256 _heroType, bool _isActive) public onlyOwner {
        cardsPaymentsTypes.push(
            CardsPaymentsTypes({
                token: _token,
                tokenQty: _tokenQty,
                heroType: _heroType,
                isActive: _isActive
            })
        );
    }

    function setCardsPaymentsTypes(uint256 _pid, IBEP20 _token, uint256 _tokenQty, uint256 _heroType, bool _isActive) public onlyOwner {
        cardsPaymentsTypes[_pid].token = _token;
        cardsPaymentsTypes[_pid].tokenQty = _tokenQty;
        cardsPaymentsTypes[_pid].heroType = _heroType;
        cardsPaymentsTypes[_pid].isActive = _isActive;
    }

    function buyHeroCard(uint256 _cardsPaymentsTypePid) public onlyIfIsActive returns (uint256) {
        CardsPaymentsTypes storage cardsPaymentsTypeSelected = cardsPaymentsTypes[_cardsPaymentsTypePid];

        require(cardsPaymentsTypeSelected.isActive, "This option is not available");
        //require(cardsPaymentsTypeSelected.token.balanceOf(msg.sender) >= cardsPaymentsTypeSelected.tokenQty, "You don't have enough Tokens");

        cardsPaymentsTypeSelected.token.safeTransferFrom(address(msg.sender), address(this), cardsPaymentsTypeSelected.tokenQty);

        uint256 tokenCount = nftMasterAddress.mintNFTHero(cardsPaymentsTypeSelected.heroType, address(msg.sender));

        emit BuyHeroCard(msg.sender, _cardsPaymentsTypePid, tokenCount);

        return tokenCount;
    }
}