// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "./SafeMath.sol";

error FundsNotReleasedYet(uint256 releaseTime);

contract Vesting {
    using SafeMath for uint256;

    struct VestingSchedule {
        uint256 base;
        uint256 startReleaseAt;
        uint256 releaseDuration;
        uint256 endReleaseAt;
    }

    mapping(address => VestingSchedule) private vestingSchedules;

    /** @dev Modifier: Checks whether the funds for the specified `account` with a balance are released.
        * @param account The address of the account to check for released funds.
        * @param balance The balance of the account to be checked for released funds.
        */
    modifier onlyReleased(address account, uint256 balance) {
        if (vestingSchedules[account].base != 0 && block.timestamp < vestingSchedules[account].endReleaseAt ) {
            require(
                block.timestamp >= calculateReleaseTime(account,balance),
                "FundsNotReleasedYet"
            );
        }
        _;
    }


    function calculateReleaseTime(address account, uint256 balance) internal view returns (uint256) {
        return vestingSchedules[account].startReleaseAt + SafeMath.div(SafeMath.mul(vestingSchedules[account].base-balance, vestingSchedules[account].releaseDuration), vestingSchedules[account].base);
    }

    function whenWillRelease(address account, uint256 balance) external view returns (uint256) {
        return calculateReleaseTime(account, balance);
    }

    function setVesting(
        address account,
        uint256 base,
        uint256 startReleaseAt,
        uint256 releaseDuration
    ) internal {
        vestingSchedules[account] = VestingSchedule(
            base,
            startReleaseAt,
            releaseDuration,
            startReleaseAt.add(releaseDuration)
        );
    }
}
