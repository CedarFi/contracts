pragma solidity 0.8.19;

import {IVotes} from "./governance/IVotes.sol";
import {IVoter} from "contracts/interfaces/IVoter.sol";

import {IGovernor} from "./governance/IGovernor.sol";
import {GovernorSimple} from "./governance/GovernorSimple.sol";
import {GovernorCountingMajority} from "./governance/GovernorCountingMajority.sol";
import {GovernorSimpleVotes} from "./governance/GovernorSimpleVotes.sol";

contract EpochGovernor is GovernorSimple, GovernorCountingMajority, GovernorSimpleVotes {
    constructor(
        address _forwarder,
        IVotes _ve,
        address _minter,
        IVoter _voter
    ) GovernorSimple(_forwarder, "Epoch Governor", _minter, _voter) GovernorSimpleVotes(_ve) {}

    function votingDelay() public pure override(IGovernor) returns (uint256) {
        return 1;
    }

    function votingPeriod() public pure override(IGovernor) returns (uint256) {
        return (1 weeks);
    }
}
