// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./StakingReserve.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Staking is Ownable {
    using Counters for Counters.Counter;
    StakingReserve public immutable reserve;
    IERC20 public immutable gold;
    event StakeUpdate(
        address account,
        uint256 packageId,
        uint256 amount,
        uint256 totalProfit
    );
    event StakeReleased(
        address account,
        uint256 packageId,
        uint256 amount,
        uint256 totalProfit
    );
    struct StakePackage {
        uint256 rate;
        uint256 decimal;
        uint256 minStaking;
        uint256 lockTime;
        bool isOffline;
    }
    struct StakingInfo {
        uint256 startTime;
        uint256 timePoint;
        uint256 amount;
        uint256 totalProfit;
    }
    Counters.Counter private _stakePackageCount;
    mapping(uint256 => StakePackage) public stakePackages;
    mapping(address => mapping(uint256 => StakingInfo)) public stakes;

    /**
     * @dev Initialize
     * @notice This is the initialize function, run on deploy event
     * @param tokenAddr_ address of main token
     * @param reserveAddress_ address of reserve contract
     */
    constructor(address tokenAddr_, address reserveAddress_) {
        gold = IERC20(tokenAddr_);
        reserve = StakingReserve(reserveAddress_);
    }

    /**
     * @dev Add new staking package
     * @notice New package will be added with an id
     */
    function addStakePackage(
        uint256 rate_,
        uint256 decimal_,
        uint256 minStaking_,
        uint256 lockTime_
    ) external onlyOwner {
        require(rate_ >= 0, "Staking: rate_ invalid");
        require(decimal_ >= 0, "Staking: decimal_ invalid");
        require(minStaking_ > 0, "Staking: minStaking_ invalid");
        require(lockTime_ >= 0, "Staking: lockTime_ invalid");

        _stakePackageCount.increment();
        uint256 _stakePackageId = _stakePackageCount.current();
        stakePackages[_stakePackageId] = StakePackage({
                rate: rate_,
                decimal: decimal_,
                minStaking: minStaking_,
                lockTime: lockTime_,
                isOffline: false
            });
    }

    /**
     * @dev Remove an stake package
     * @notice A stake package with packageId will be set to offline
     * so none of new staker can stake to an offine stake package
     */
    function removeStakePackage(uint256 packageId_) external onlyOwner {
        require(stakePackages[packageId_].minStaking > 0, "Staking: package is not exists");
        require(stakePackages[packageId_].isOffline == false, "Staking: package is offline already");
        stakePackages[packageId_].isOffline = true;
    }

    /**
     * @dev User stake amount of gold to stakes[address][packageId]
     * @notice if is there any amount of gold change in the stake package,
     * calculate the profit and add it to total Profit,
     * otherwise just add completely new stake. 
     */
    function stake(uint256 amount_, uint256 packageId_) external {
        require(amount_ > 0, "Staking: Amount must be greater than 0");
        require(stakePackages[packageId_].minStaking > 0, "Staking: package not exists");
        require(stakePackages[packageId_].minStaking <= amount_, "Staking: amount invalid");
        require(stakePackages[packageId_].isOffline == false, "Staking: package is offline");
        uint256 allowance = gold.allowance(msg.sender, address(this));
        require(allowance >= amount_, "Staking: allowance invalid");
        gold.transferFrom(
            address(msg.sender),
            address(reserve),
            amount_
        );

        StakingInfo storage stake = stakes[msg.sender][packageId_];
        if (stake.amount > 0) {
            stake.totalProfit = calculateProfit(packageId_);
        } else {
            stake.startTime = block.timestamp;
        }
        stake.timePoint = block.timestamp;
        stake.amount = stake.amount + amount_;

        emit StakeUpdate(msg.sender, packageId_, amount_, stake.totalProfit);
    }
    /**
     * @dev Take out all the stake amount and profit of account's stake from reserve contract
     */
    function unStake(uint256 packageId_) external {
        require(stakePackages[packageId_].minStaking > 0, "Staking: package not exists");
        require(stakePackages[packageId_].lockTime < block.timestamp, "Staking: package is still locked");
        StakingInfo memory stake = stakes[msg.sender][packageId_];
        require(stake.amount > 0, "Staking: user amount must be greater than zero");
        uint256 totalProfit = calculateProfit(packageId_);
        uint256 amount = stake.amount;
        uint256 total = totalProfit + stake.amount;
        uint256 reserveBalance = reserve.getBalanceOfReserve();
        require(reserveBalance >= total, "Staking: reserveBalance invalid");
        delete stakes[msg.sender][packageId_];
        reserve.distributeGold(
            address(msg.sender),
            total
        );

        emit StakeReleased(msg.sender, packageId_, amount, totalProfit);
    }
    /**
     * @dev calculate current profit of an package of user known packageId
     */

    function calculateProfit(uint256 packageId_)
        public
        view
        returns (uint256)
    {
        require(stakePackages[packageId_].minStaking > 0, "Staking: package not exists");
        StakingInfo memory stake = stakes[msg.sender][packageId_];
        if (stake.amount == 0) {
            return 0;
        }
        uint256 aprOfPackage = getAprOfPackage(packageId_);
        uint256 numberOfDays = (block.timestamp - stake.timePoint) / (60 * 60 * 24);
        return (stake.amount * (aprOfPackage / 365) * numberOfDays) / 1e18 + stake.totalProfit;
    }

    function getAprOfPackage(uint256 packageId_)
        public
        view
        returns (uint256)
    {
        StakePackage memory stakePackage = stakePackages[packageId_];
        uint256 rate = (stakePackage.rate * 1e18) / 10 ** (stakePackage.decimal + 2);
        return rate;
    }

    function getStakePackage(uint256 packageId_)
        public
        view
        returns (StakePackage memory)
    {
        return stakePackages[packageId_];
    }
}
