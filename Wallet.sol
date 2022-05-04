pragma solidity 0.6.12;

import './lib/SafeMath.sol';
import './lib/IBEP20.sol';
import './lib/SafeBEP20.sol';
import './lib/Ownable.sol';
import './lib/ReentrancyGuard.sol';

contract Wallet is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    struct UserInfo {
        uint256 amount;
        uint256 lastWithdraw;
    }

    mapping (IBEP20 => mapping (address => UserInfo)) public userInfo;

    mapping(IBEP20 => bool) public tokensToSaveExistence;
    IBEP20[] public tokensToSave;
    mapping(IBEP20 => uint256) public tokenDepositToWalletFunds;
    mapping(IBEP20 => uint256) public tokenDepositToUserFunds;
    mapping(IBEP20 => uint256) public tokenWithdrawnByUser;
    mapping(IBEP20 => uint256) public tokenFeeWithdraw;

    mapping(address => bool) public canDepositUserTokens;

    uint256 public constant MAXIMUM_INITIAL_WITHDRAW_FEE = 8000;
    uint256 public constant MINIMUM_DAILY_PERCENTAGE_SUBSTRACTION = 500;

    uint256 public initialWithdrawFee = 8000;
    uint256 public dailyPercentageSubtraction = 500;

    // Referral Bonus in basis points. Initially set to 3%
    uint256 public refBonusBP = 300;
    // Max referral commission rate: 3%.
    uint16 public constant MAXIMUM_REFERRAL_BP = 300;

    mapping(address => address) public referrers;
    mapping(address => address[]) public referredUsers;

    event Withdraw(IBEP20 token, address user, uint256 percentWithdrawFee, uint256 userAmountInWallet);
    event WithdrawAll(address user);
    event AddAddressCanDepositUserTokens(address owner, address addressCanDeposit, bool status);
    event DepositToUserBalance(IBEP20 token, address user, uint256 amount, uint256 totalUserAmount);
    event AddTokensToSave(IBEP20 token, address owner);
    event SetInitialWithdrawFee(uint256 initialWithdrawFee, address owner);
    event SetDailyPercentageSubtraction(uint256 dailyPercentageSubtraction, address owner);
    event PayReferralCommission(address _user, address referrer, IBEP20 _token, uint256 refBonusEarned);
    event DepositTokenToWalletFunds(IBEP20 token, uint256 _tokenQty, uint256 tokenDepositToWalletFunds);

    function withdraw(IBEP20 _token) public {
        UserInfo storage currentUserInfo = userInfo[_token][msg.sender];
        uint256 userAmountInWallet = currentUserInfo.amount;

        uint256 percentWithdrawFee = getCurrentWithdrawFeePercent(_token, msg.sender);

        if (percentWithdrawFee > 0) {
            uint256 withdrawFee = userAmountInWallet.mul(percentWithdrawFee).div(10000);
            uint256 amountToWithdraw = userAmountInWallet.sub(withdrawFee);
            _token.safeTransfer(address(0x00dead), withdrawFee);
            _token.safeTransfer(msg.sender, amountToWithdraw);

            tokenFeeWithdraw[_token] = tokenFeeWithdraw[_token].add(withdrawFee);
            tokenWithdrawnByUser[_token] = tokenWithdrawnByUser[_token].add(amountToWithdraw);

        } else {
            _token.safeTransfer(msg.sender, userAmountInWallet);
            tokenWithdrawnByUser[_token] = tokenWithdrawnByUser[_token].add(userAmountInWallet);
        }
        currentUserInfo.amount = 0;
        currentUserInfo.lastWithdraw = block.timestamp;
        emit Withdraw(_token, msg.sender, percentWithdrawFee, userAmountInWallet);
    }

    function withdrawAllMyTokens() public {
        uint256 length = tokensToSave.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            withdraw(tokensToSave[pid]);
        }
        emit WithdrawAll(msg.sender);
    }

    function getCurrentWithdrawFeePercent(IBEP20 _token, address _user) public view returns (uint256) {
        UserInfo memory currentUserInfo = userInfo[_token][_user];

        uint256 daysDiff = (block.timestamp.sub(currentUserInfo.lastWithdraw)).div(60).div(60).div(24);
        uint256 percentageToSubtract = daysDiff.mul(dailyPercentageSubtraction);

        uint256 currentWithdrawFeePercent = 0;
        if (percentageToSubtract < initialWithdrawFee) {
            currentWithdrawFeePercent = initialWithdrawFee.sub(percentageToSubtract);
        }

        return currentWithdrawFeePercent;
    }

    function seeMyTokens(IBEP20 _token, address _user) public view returns (uint256) {
        UserInfo memory currentUserInfo = userInfo[_token][_user];
        return currentUserInfo.amount;
    }

    function getNumberOfReferredsByReferrer(address _referrer) public view returns(uint256) {
        return referredUsers[_referrer].length;
    }

    function addAddressCanDepositUserTokens(address _address, bool _canDepositUserTokens) public onlyOwner {
        canDepositUserTokens[_address] = _canDepositUserTokens;
        emit AddAddressCanDepositUserTokens(msg.sender, _address, _canDepositUserTokens);
    }

    function depositToUserBalance(IBEP20 _token, address _user, uint256 _amount) public {
        require(canDepositUserTokens[msg.sender] == true, "You can't deposit tokens ;)");
        UserInfo storage currentUserInfo = userInfo[_token][_user];
        currentUserInfo.amount = currentUserInfo.amount.add(_amount);

        if (currentUserInfo.lastWithdraw == 0) {
            currentUserInfo.lastWithdraw = block.timestamp;
        }

        payReferralCommission(_token, _user, _amount);

        tokenDepositToUserFunds[_token] = tokenDepositToUserFunds[_token].add(_amount);

        emit DepositToUserBalance(_token, _user, _amount, currentUserInfo.amount);
    }

    function addTokensToSave(IBEP20 _token) public onlyOwner {
        require(tokensToSaveExistence[_token] == false, "This token has been added previously");
        tokensToSave.push(_token);
        tokensToSaveExistence[_token] = true;
        emit AddTokensToSave(_token, msg.sender);
    }

    function setInitialWithdrawFee(uint256 _initialWithdrawFee) public onlyOwner {
        require(_initialWithdrawFee < MAXIMUM_INITIAL_WITHDRAW_FEE);
        initialWithdrawFee = _initialWithdrawFee;
        emit SetInitialWithdrawFee(_initialWithdrawFee, msg.sender);
    }

    function setDailyPercentageSubtraction(uint256 _dailyPercentageSubtraction) public onlyOwner {
        require(_dailyPercentageSubtraction <= initialWithdrawFee);
        require(_dailyPercentageSubtraction >= MINIMUM_DAILY_PERCENTAGE_SUBSTRACTION);
        dailyPercentageSubtraction = _dailyPercentageSubtraction;
        emit SetDailyPercentageSubtraction(_dailyPercentageSubtraction, msg.sender);
    }

    function setReferreral(address _user, address _referrer) public {
        if (_referrer == address(_referrer) && referrers[_user] == address(0) && _referrer != address(0) && _referrer != _user) {
            referrers[_user] = _referrer;
            referredUsers[_referrer].push(
                _user
            );
        }
    }

    function getReferral(address _user) public view returns (address) {
        return referrers[_user];
    }

    function payReferralCommission(IBEP20 _token, address _user, uint256 _pending) internal {
        address referrer = getReferral(_user);
        if (referrer != address(0) && referrer != _user && refBonusBP > 0) {
            uint256 refBonusEarned = _pending.mul(refBonusBP).div(10000);

            UserInfo storage referrerUserInfo = userInfo[_token][referrer];
            referrerUserInfo.amount = referrerUserInfo.amount.add(refBonusEarned);

            if (referrerUserInfo.lastWithdraw == 0) {
                referrerUserInfo.lastWithdraw = block.timestamp;
            }

            tokenDepositToUserFunds[_token] = tokenDepositToUserFunds[_token].add(refBonusEarned);

            emit PayReferralCommission(_user, referrer, _token, refBonusEarned);
        }
    }

    function depositTokenToWalletFunds(IBEP20 _token, uint256 _tokenQty) public {
        require(tokensToSaveExistence[_token] == true, "This token can't be deposit");
        require(_token.balanceOf(msg.sender) >= _tokenQty);
        _token.safeTransferFrom(address(msg.sender), address(this), _tokenQty);
        tokenDepositToWalletFunds[_token] = tokenDepositToWalletFunds[_token].add(_tokenQty);
        emit DepositTokenToWalletFunds(_token, _tokenQty, tokenDepositToWalletFunds[_token]);
    }
}