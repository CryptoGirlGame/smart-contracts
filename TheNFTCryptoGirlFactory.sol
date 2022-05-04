pragma solidity ^0.6.12;

import './lib/Ownable.sol';
import './lib/SafeMath.sol';
import "./lib-erc/ERC721.sol";


contract TheNFTCryptoGirlFactory is ERC721, Ownable {

    using SafeMath for uint256;

    constructor() ERC721("CryptoGirl.finance | NFT", "CGNFT") public {

    }

    event NewHero(uint256 _heroType, uint256 level, uint256 defense, uint256 attack, uint256 speed, uint256 fly, uint256 now);
    event NewCity(string _name, uint256 gangsters, uint256 citizens, uint256 difficulty, uint256 now);
    event NewVillain(uint256 _villainType, uint256 level, uint256 defense, uint256 attack, uint256 speed, uint256 fly, uint256 now);

    uint256 public tokenCount;

    mapping(uint256 => uint256) public tokenTypeByTokenId;
    //0 => hero
    //1 => city
    //2 => villain

    mapping(address => bool) public canMintHero;
    mapping(address => bool) public canMintCity;
    mapping(address => bool) public canMintVillain;
    mapping(address => bool) public canUpgradeNFT;

    struct Hero {
        uint256 heroType;
        uint256 level;
        uint256 defense;
        uint256 attack;
        uint256 speed;
        uint256 fly;
        uint256 bornAt;
    }

    struct HeroType {
        string name;
        uint256 minPropertyValue;
        uint256 maxPropertyValue;
        bool canMint;
    }

    HeroType[] public heroesTypes;

    mapping(uint256 => Hero) public heroes;

    struct City {
        string name;
        uint256 gangsters;
        uint256 citizens;
        uint256 difficulty;
        uint256 bornAt;
    }

    mapping(uint256 => City) public cities;

    struct Villain {
        uint256 villainType;
        uint256 cityId;
        uint256 level;
        uint256 defense;
        uint256 attack;
        uint256 speed;
        uint256 fly;
        uint256 bornAt;
    }

    struct VillainType {
        string name;
        uint256 minPropertyValue;
        uint256 maxPropertyValue;
        bool canMint;
    }

    VillainType[] public villainsTypes;

    mapping(uint256 => Villain) public villains;

    //cityId -> VillainType -> idVillains
    mapping (uint256 => mapping (uint256 => uint256[])) public cityVillainTypeIdVillain;

    function cityVillainTypeIdVillainLength(uint256 _cityId, uint256 _villainType) public view returns (uint256) {
        return cityVillainTypeIdVillain[_cityId][_villainType].length;
    }

    function mintNFTHero(uint256 _heroType, address _to) public returns (uint256) {
        require(canMintHero[msg.sender] == true, "You can't mint hero's ;)");

        HeroType storage heroType = heroesTypes[_heroType];

        uint256 minPropertyValue = heroType.minPropertyValue;
        uint256 maxPropertyValue = heroType.maxPropertyValue;

        uint256 level = getRandom(7) + 1;

        uint256 defense = (((getRandom(7) + 3) * 3) % 10) + 1;
        uint256 attack = (((getRandom(3) + 6) * 6) % 10) + 1;
        uint256 speed = (((getRandom(6) + 9) * 9) % 10) + 1;
        uint256 fly = (((getRandom(9) + 7) * 7) % 10) + 1;

        if (defense < minPropertyValue) {
            defense = minPropertyValue;
        } else if (defense > maxPropertyValue) {
            defense = maxPropertyValue;
        }

        if (attack < minPropertyValue) {
            attack = minPropertyValue;
        } else if (attack > maxPropertyValue) {
            attack = maxPropertyValue;
        }

        if (speed < minPropertyValue) {
            speed = minPropertyValue;
        } else if (speed > maxPropertyValue) {
            speed = maxPropertyValue;
        }

        if (fly < minPropertyValue) {
            fly = minPropertyValue;
        } else if (fly > maxPropertyValue) {
            fly = maxPropertyValue;
        }

        if (level <= 7) {
            level = 1;
        } else if (level <= 9) {
            level = 2;
        } else {
            level = 3;
        }

        tokenCount = tokenCount.add(1);

        Hero memory hero = Hero(_heroType, level, defense, attack, speed, fly, now);
        heroes[tokenCount] = hero;
        _mint(_to, tokenCount);

        tokenTypeByTokenId[tokenCount] = 0;

        emit NewHero(_heroType, level, defense, attack, speed, fly, now);

        return tokenCount;
    }

    function mintNFTCity(string memory _name, address _to) public returns (uint256) {
        require(canMintCity[msg.sender] == true, "You can't mint cities ;)");

        uint256 gangsters = (((getRandom(9) + 3) * 3) % 10) + 1;
        uint256 citizens = (((getRandom(3) + 6) * 6) % 10) + 1;
        uint256 difficulty = (((getRandom(6) + 9) * 9) % 10) + 1;

        tokenCount = tokenCount.add(1);

        City memory city = City(_name, gangsters, citizens, difficulty, now);
        cities[tokenCount] = city;
        _mint(_to, tokenCount);

        tokenTypeByTokenId[tokenCount] = 1;

        emit NewCity(_name, gangsters, citizens, difficulty, now);

        return tokenCount;
    }

    function mintNFTVillain(uint256 _villainType, uint256 _cityId, address _to) public returns (uint256) {
        require(canMintVillain[msg.sender] == true, "You can't mint villain's ;)");
        require(cities[_cityId].bornAt > 0, "You can't mint villain's ;)");

        uint256 level = getRandom(9) + 1;

        VillainType storage villainType = villainsTypes[_villainType];

        uint256 minPropertyValue = villainType.minPropertyValue;
        uint256 maxPropertyValue = villainType.maxPropertyValue;

        uint256 defense = (((getRandom(7) + 3) * 3) % 10) + 1;
        uint256 attack = (((getRandom(9) + 6) * 6) % 10) + 1;
        uint256 speed = (((getRandom(6) + 9) * 9) % 10) + 1;
        uint256 fly = (((getRandom(3) + 7) * 7) % 10) + 1;

        if (defense < minPropertyValue) {
            defense = minPropertyValue;
        } else if (defense > maxPropertyValue) {
            defense = maxPropertyValue;
        }

        if (attack < minPropertyValue) {
            attack = minPropertyValue;
        } else if (attack > maxPropertyValue) {
            attack = maxPropertyValue;
        }

        if (speed < minPropertyValue) {
            speed = minPropertyValue;
        } else if (speed > maxPropertyValue) {
            speed = maxPropertyValue;
        }

        if (fly < minPropertyValue) {
            fly = minPropertyValue;
        } else if (fly > maxPropertyValue) {
            fly = maxPropertyValue;
        }

        if (level <= 7) {
            level = 1;
        } else if (level <= 9) {
            level = 2;
        } else {
            level = 3;
        }

        tokenCount = tokenCount.add(1);

        Villain memory villain = Villain(_villainType, _cityId, level, defense, attack, speed, fly, now);
        villains[tokenCount] = villain;
        _mint(_to, tokenCount);

        tokenTypeByTokenId[tokenCount] = 2;
        cityVillainTypeIdVillain[_cityId][_villainType].push(tokenCount);

        emit NewVillain(_villainType, level, defense, attack, speed, fly, now);

        return tokenCount;
    }

    function getRandom(uint256 n) private view returns (uint) {
        return uint(keccak256(abi.encodePacked((block.timestamp * block.number) - block.timestamp))) * tokenCount * n % 10;
    }

}
