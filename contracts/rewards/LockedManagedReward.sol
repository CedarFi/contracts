pragma solidity 0.8.19;

import {ManagedReward} from "./ManagedReward.sol";
import {IVotingEscrow} from "../interfaces/IVotingEscrow.sol";

contract LockedManagedReward is ManagedReward {
    constructor(address _forwarder, address _voter) ManagedReward(_forwarder, _voter) {}

    /// @inheritdoc ManagedReward
    /// @dev Called by VotingEscrow to retrieve locked rewards
    function getReward(uint256 tokenId, address[] memory tokens) external override nonReentrant {
        address sender = _msgSender();
        if (sender != ve) revert NotVotingEscrow();
        if (tokens.length != 1) revert NotSingleToken();
        if (tokens[0] != IVotingEscrow(ve).token()) revert NotEscrowToken();

        _getReward(sender, tokenId, tokens);
    }

    /// @inheritdoc ManagedReward
    /// @dev Called by VotingEscrow to add rebases / compounded rewards for disbursement
    function notifyRewardAmount(address token, uint256 amount) external override nonReentrant {
        address sender = _msgSender();
        if (sender != ve) revert NotVotingEscrow();
        if (token != IVotingEscrow(ve).token()) revert NotEscrowToken();

        _notifyRewardAmount(sender, token, amount);
    }
}
