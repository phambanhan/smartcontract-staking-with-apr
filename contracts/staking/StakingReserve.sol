// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Staking reserve is a contract that holds tokens from staking actions and allows
//  the staking contract to take the amount to interest their profit

contract StakingReserve is Ownable {
    IERC20 public mainToken;
    address public stakeAddress;

    constructor(address _mainToken) {
        mainToken = IERC20(_mainToken);
    }

    function getBalanceOfReserve() public view returns (uint256) {
        return mainToken.balanceOf(address(this));
    }

    function setStakeAdress(address _stakeAddress) external onlyOwner {
        require(_stakeAddress != address(0), "StakingReserve: _stakeAddress is zero address");
        stakeAddress = _stakeAddress;
    }
    function distributeGold(address _recipient, uint256 _amount) external {
        require(msg.sender == stakeAddress, "StakingReserve: stakeAddress invalid");
        mainToken.transfer(_recipient, _amount);
    }
}
