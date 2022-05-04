pragma solidity 0.6.12;

import './lib/SafeMath.sol';
import './lib/IBEP20.sol';
import './lib/SafeBEP20.sol';
import './lib/Ownable.sol';
import './lib/ReentrancyGuard.sol';

//refillMasterChefsimport "@nomiclabs/buidler/console.sol";

contract Bank is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    address public masterChefCGIRL;
    address public masterChefEGIRL;

    constructor(
        address _masterChefCGIRL,
        address _masterChefEGIRL
    ) public {
        masterChefCGIRL = _masterChefCGIRL;
        masterChefEGIRL = _masterChefEGIRL;
    }

    event GetTokens(address indexed masterchef, IBEP20 _token, uint256 amount);

    function transferFromMasterChefsToUser(IBEP20 _token, address _to, uint256 _amount) public nonReentrant {
        require(msg.sender == masterChefCGIRL || msg.sender == masterChefEGIRL, 'Only MasterChefs can get this Tokens grrrrrrr...');

        _token.safeTransfer(_to, _amount);

        emit GetTokens(_to, _token, _amount);
    }
}