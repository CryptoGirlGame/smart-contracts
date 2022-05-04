pragma solidity 0.6.12;

import "./TheNFTCryptoGirlFactory.sol";

contract TheNFTCryptoGirlHelper is TheNFTCryptoGirlFactory {
    using SafeMath for uint256;

    uint256 public herosTypeCount;
    uint256 public villainsTypeCount;

    function totalSupply() public view returns (uint256) {
        return tokenCount;
    }

    function addHeroType(string memory _name, uint256 _minPropertyValue, uint256 _maxPropertyValue, bool _canMint) public onlyOwner {

        herosTypeCount = herosTypeCount.add(1);

        heroesTypes.push(
            HeroType({
            name: _name,
            minPropertyValue: _minPropertyValue,
            maxPropertyValue: _maxPropertyValue,
            canMint: _canMint
        })
        );
    }

    function setHeroType(uint256 _pid, string memory _name, uint256 _minPropertyValue, uint256 _maxPropertyValue, bool _canMint) public onlyOwner {
        heroesTypes[_pid].name = _name;
        heroesTypes[_pid].minPropertyValue = _minPropertyValue;
        heroesTypes[_pid].maxPropertyValue = _maxPropertyValue;
        heroesTypes[_pid].canMint = _canMint;
    }

    function addVillainType(string memory _name, uint256 _minPropertyValue, uint256 _maxPropertyValue, bool _canMint) public onlyOwner {

        villainsTypeCount = villainsTypeCount.add(1);

        villainsTypes.push(
            VillainType({
                name: _name,
                minPropertyValue: _minPropertyValue,
                maxPropertyValue: _maxPropertyValue,
                canMint: _canMint
            })
        );
    }

    function setVillainType(uint256 _pid, string memory _name, uint256 _minPropertyValue, uint256 _maxPropertyValue, bool _canMint) public onlyOwner {
        villainsTypes[_pid].name = _name;
        villainsTypes[_pid].minPropertyValue = _minPropertyValue;
        villainsTypes[_pid].maxPropertyValue = _maxPropertyValue;
        villainsTypes[_pid].canMint = _canMint;
    }

    function addCanMintHero(address _address, bool _canMintHero) public onlyOwner {
        canMintHero[_address] = _canMintHero;
    }

    function addCanMintCity(address _address, bool _canMintCity) public onlyOwner {
        canMintCity[_address] = _canMintCity;
    }

    function addCanMintVillain(address _address, bool _canMintVillain) public onlyOwner {
        canMintVillain[_address] = _canMintVillain;
    }

    function addCanUpgradeNFT(address _address, bool _canUpgrade) public onlyOwner {
        canUpgradeNFT[_address] = _canUpgrade;
    }

    function tokensOfOwner(address _owner) external view returns(uint256[] memory ownerTokens) {
        uint256 tokenCount = balanceOf(_owner);

        if (tokenCount == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 totalNFTs = totalSupply();
            uint256 i = 0;

            uint256 tId;

            for (tId = 1; tId <= totalNFTs; tId++) {
                if (_owners[tId] == _owner) {
                    result[i] = tId;
                    i++;
                }
            }

            return result;
        }
    }

    function getTokenLevel(uint256 _tokenId) public view returns (uint256) {
        uint256 tokenType = tokenTypeByTokenId[_tokenId];
        uint256 level = 0;

        if (tokenType == 0) {
            level = heroes[_tokenId].level;
        } else if (tokenType == 2) {
            level = villains[_tokenId].level;
        }

        return level;
    }

    function upgradeLevel(uint256 _tokenId, uint256 _nLevels) public {
        require(canUpgradeNFT[msg.sender] == true);

        uint256 currentNFTLevel = getTokenLevel(_tokenId);
        uint256 newLevel = currentNFTLevel.add(_nLevels);

        require(newLevel <= 100);

        uint256 tokenType = tokenTypeByTokenId[_tokenId];

        if (tokenType == 0) {
            heroes[_tokenId].level = heroes[_tokenId].level.add(_nLevels);
        } else if (tokenType == 2) {
            villains[_tokenId].level = villains[_tokenId].level.add(_nLevels);
        }
    }

    function getTokenPropertyLevel(uint256 _tokenId, uint256 _propertyId) public view returns (uint256) {
        uint256 tokenType = tokenTypeByTokenId[_tokenId];
        uint256 propertyValue = 0;

        if (tokenType == 0) {

            if (_propertyId == 1) {
                propertyValue = heroes[_tokenId].defense;
            } else if (_propertyId == 2) {
                propertyValue = heroes[_tokenId].attack;
            } else if (_propertyId == 3) {
                propertyValue = heroes[_tokenId].speed;
            } else if (_propertyId == 4) {
                propertyValue = heroes[_tokenId].fly;
            }

        } else if (tokenType == 2) {

            if (_propertyId == 1) {
                propertyValue = villains[_tokenId].defense;
            } else if (_propertyId == 2) {
                propertyValue = villains[_tokenId].attack;
            } else if (_propertyId == 3) {
                propertyValue = villains[_tokenId].speed;
            } else if (_propertyId == 4) {
                propertyValue = villains[_tokenId].fly;
            }

        }

        return propertyValue;
    }

    function upgradeProperty(uint256 _tokenId, uint256 _propertyId, uint256 _nValues) public {
        require(canUpgradeNFT[msg.sender] == true);

        uint256 currentNFTPropertyLevel = getTokenPropertyLevel(_tokenId, _propertyId);
        uint256 newLevel = currentNFTPropertyLevel.add(_nValues);

        require(newLevel <= 10);

        uint256 tokenType = tokenTypeByTokenId[_tokenId];

        if (tokenType == 0) {

            if (_propertyId == 1) {
                heroes[_tokenId].defense = heroes[_tokenId].defense.add(_nValues);
            } else if (_propertyId == 2) {
                heroes[_tokenId].attack = heroes[_tokenId].attack.add(_nValues);
            } else if (_propertyId == 3) {
                heroes[_tokenId].speed = heroes[_tokenId].speed.add(_nValues);
            } else if (_propertyId == 4) {
                heroes[_tokenId].fly = heroes[_tokenId].fly.add(_nValues);
            }

        } else if (tokenType == 2) {

            if (_propertyId == 1) {
                villains[_tokenId].defense = villains[_tokenId].defense.add(_nValues);
            } else if (_propertyId == 2) {
                villains[_tokenId].attack = villains[_tokenId].attack.add(_nValues);
            } else if (_propertyId == 3) {
                villains[_tokenId].speed = villains[_tokenId].speed.add(_nValues);
            } else if (_propertyId == 4) {
                villains[_tokenId].fly = villains[_tokenId].fly.add(_nValues);
            }

        }
    }
}