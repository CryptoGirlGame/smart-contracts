pragma solidity 0.6.12;

import './lib/SafeMath.sol';
import './lib/IBEP20.sol';
import './lib/SafeBEP20.sol';
import './lib/Ownable.sol';
import './lib/ReentrancyGuard.sol';

import './TheNFTCryptoGirl.sol';

import './OraclePrice.sol';

contract UpgradeNFTCryptoGirl is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    address public feeAddress;

    TheNFTCryptoGirl public nftMasterAddress;
    IBEP20 public cryptoGirlToken;
    IBEP20 public energyCryptoGirlToken;

    OraclePrice public oraclePriceAddress;

    bool public thisContractIsActive = true;

    uint256 public priceInUSDFirstLevelUpgrade;
    uint256 public priceInUSDFirstPropertyUpgrade;
    uint256 public bnbLevelUpgrade;
    uint256 public bnbLevelPropertyUpgrade;

    uint256 public percentExtraPerLevelNumber = 200;
    uint256 public percentExtraPerPropertyNumber = 500;

    event SetFeeAddress(address indexed user, address indexed _feeAddress);
    event TestBnbPrice(uint256 msgValue, uint256 bnbExpected);

    constructor(
        address _feeAddress,
        IBEP20 _cryptoGirlToken,
        IBEP20 _energyCryptoGirlToken,
        uint256 _priceInUSDFirstLevelUpgrade,
        uint256 _priceInUSDFirstPropertyUpgrade,
        uint256 _bnbLevelUpgrade,
        uint256 _bnbLevelPropertyUpgrade
    ) public {
        feeAddress = _feeAddress;
        cryptoGirlToken = _cryptoGirlToken;
        energyCryptoGirlToken = _energyCryptoGirlToken;
        priceInUSDFirstLevelUpgrade = _priceInUSDFirstLevelUpgrade;
        priceInUSDFirstPropertyUpgrade = _priceInUSDFirstPropertyUpgrade;
        bnbLevelUpgrade = _bnbLevelUpgrade;
        bnbLevelPropertyUpgrade = _bnbLevelPropertyUpgrade;
    }

    modifier onlyIfIsActive() {
        require(thisContractIsActive, "You can use, if is active");
        _;
    }

    function setFeeAddress(address _feeAddress) public {
        require(_feeAddress != address(0), "setFeeAddress: invalid address");
        require(msg.sender == feeAddress, "setFeeAddress: FORBIDDEN");
        feeAddress = _feeAddress;
        emit SetFeeAddress(msg.sender, _feeAddress);
    }

    function setContractState(bool _newContractState) public onlyOwner {
        thisContractIsActive = _newContractState;
    }

    function changeNFTMasterAddress(TheNFTCryptoGirl _address) public onlyOwner {
        nftMasterAddress = _address;
    }

    function changeOracleAddress(OraclePrice _address) public onlyOwner {
        oraclePriceAddress = _address;
    }

    modifier onlyIfIsTheOwnerOfNFT(uint256 _tokenId) {
        require(nftMasterAddress.ownerOf(_tokenId) == msg.sender, "You can use, if is active");
        _;
    }

    function getNextPriceUpgradeLevel(uint256 _tokenId, uint256 _nLevels) public view returns (
        uint256 upgradePriceInUSD,
        uint256 cryptoGirlQty,
        uint256 energyCryptoGirlQty,
        uint256 bnbQty,
        bool upgradeIsPossible
    ) {
        uint256 currentNFTLevel = nftMasterAddress.getTokenLevel(_tokenId);

        upgradePriceInUSD = 0;
        cryptoGirlQty = 0;
        energyCryptoGirlQty = 0;
        bnbQty = 0;
        upgradeIsPossible = false;

        uint256 newLevel = currentNFTLevel.add(_nLevels);

        if (newLevel <= 100 && currentNFTLevel < newLevel) {
            upgradeIsPossible = true;

            uint256 iLevel;
            uint256 priceCurrentLevel = priceInUSDFirstLevelUpgrade;
            for (iLevel = 2; iLevel <= 100; iLevel++) {
                priceCurrentLevel = priceCurrentLevel.add(priceCurrentLevel.mul(percentExtraPerLevelNumber).div(10000));

                if (iLevel > currentNFTLevel && iLevel <= newLevel) {
                    upgradePriceInUSD = upgradePriceInUSD.add(priceCurrentLevel);
                    bnbQty = bnbQty.add(bnbLevelUpgrade);
                }
            }

            uint256 cryptoGirlPrice = oraclePriceAddress.getPrice(cryptoGirlToken);
            uint256 energyCryptoGirlPrice = oraclePriceAddress.getPrice(energyCryptoGirlToken);

            uint256 halfPrice = upgradePriceInUSD.div(2);
            cryptoGirlQty = halfPrice.mul(1e18).div(cryptoGirlPrice);
            energyCryptoGirlQty = halfPrice.mul(1e18).div(energyCryptoGirlPrice);
        }

        return (
            upgradePriceInUSD,
            cryptoGirlQty,
            energyCryptoGirlQty,
            bnbQty,
            upgradeIsPossible
        );
    }

    function upgradeToNextLevelNFTToken(uint256 _tokenId, uint256 _nLevels) public onlyIfIsTheOwnerOfNFT(_tokenId) payable {
        uint256 upgradePriceInUSD;
        uint256 cryptoGirlQty;
        uint256 energyCryptoGirlQty;
        uint256 bnbQty;
        bool upgradeIsPossible;

        (upgradePriceInUSD,cryptoGirlQty,energyCryptoGirlQty,bnbQty,upgradeIsPossible) = getNextPriceUpgradeLevel(_tokenId, _nLevels);

        require(cryptoGirlToken.balanceOf(msg.sender) >= cryptoGirlQty, "Not enough CryptoGirlToken");
        require(energyCryptoGirlToken.balanceOf(msg.sender) >= energyCryptoGirlQty, "Not enough EnergyCryptoGirlToken");
        require(msg.value == bnbQty, "Not enough BNB");

        payable(feeAddress).transfer(msg.value);

        cryptoGirlToken.safeTransferFrom(address(msg.sender), address(feeAddress), cryptoGirlQty);
        energyCryptoGirlToken.safeTransferFrom(address(msg.sender), address(feeAddress), energyCryptoGirlQty);

        nftMasterAddress.upgradeLevel(_tokenId, _nLevels);

        emit TestBnbPrice(msg.value, bnbQty);
    }

    function getNextPriceUpgradeProperty(uint256 _tokenId, uint256 _propertyId, uint256 _nValues) public view returns (
        uint256 upgradePriceInUSD,
        uint256 cryptoGirlQty,
        uint256 energyCryptoGirlQty,
        uint256 bnbQty,
        bool upgradeIsPossible
    ) {
        uint256 currentNFTPropertyLevel = nftMasterAddress.getTokenPropertyLevel(_tokenId, _propertyId);

        upgradePriceInUSD = 0;
        cryptoGirlQty = 0;
        energyCryptoGirlQty = 0;
        bnbQty = 0;
        upgradeIsPossible = false;

        uint256 newLevel = currentNFTPropertyLevel.add(_nValues);

        if (newLevel <= 10 && currentNFTPropertyLevel < newLevel) {
            upgradeIsPossible = true;

            uint256 iLevel;
            uint256 priceCurrentLevel = priceInUSDFirstPropertyUpgrade;
            for (iLevel = 2; iLevel <= 100; iLevel++) {
                priceCurrentLevel = priceCurrentLevel.add(currentNFTPropertyLevel.mul(percentExtraPerPropertyNumber).div(10000));

                if (iLevel > currentNFTPropertyLevel && iLevel <= newLevel) {
                    upgradePriceInUSD = upgradePriceInUSD.add(priceCurrentLevel);
                    bnbQty = bnbQty.add(bnbLevelPropertyUpgrade);
                }
            }

            uint256 cryptoGirlPrice = oraclePriceAddress.getPrice(cryptoGirlToken);
            uint256 energyCryptoGirlPrice = oraclePriceAddress.getPrice(energyCryptoGirlToken);

            uint256 halfPrice = upgradePriceInUSD.div(2);
            cryptoGirlQty = halfPrice.mul(1e18).div(cryptoGirlPrice);
            energyCryptoGirlQty = halfPrice.mul(1e18).div(energyCryptoGirlPrice);
        }

        return (
            upgradePriceInUSD,
            cryptoGirlQty,
            energyCryptoGirlQty,
            bnbQty,
            upgradeIsPossible
        );
    }

    function upgradeToNextPropertyNFTToken(uint256 _tokenId, uint256 _propertyId, uint256 _nValues) public onlyIfIsTheOwnerOfNFT(_tokenId) payable {

        uint256 upgradePriceInUSD;
        uint256 cryptoGirlQty;
        uint256 energyCryptoGirlQty;
        uint256 bnbQty;
        bool upgradeIsPossible;

        (upgradePriceInUSD,cryptoGirlQty,energyCryptoGirlQty,bnbQty,upgradeIsPossible) = getNextPriceUpgradeProperty(_tokenId, _propertyId, _nValues);

        require(cryptoGirlToken.balanceOf(msg.sender) >= cryptoGirlQty, "Not enough CryptoGirlToken");
        require(energyCryptoGirlToken.balanceOf(msg.sender) >= energyCryptoGirlQty, "Not enough EnergyCryptoGirlToken");
        require(msg.value == bnbQty, "Not enough BNB");

        payable(feeAddress).transfer(msg.value);

        cryptoGirlToken.safeTransferFrom(address(msg.sender), address(feeAddress), cryptoGirlQty);
        energyCryptoGirlToken.safeTransferFrom(address(msg.sender), address(feeAddress), energyCryptoGirlQty);

        nftMasterAddress.upgradeProperty(_tokenId, _propertyId, _nValues);
    }
}