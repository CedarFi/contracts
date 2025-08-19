pragma solidity 0.8.19;

import {Forwarder} from "@opengsn/contracts/src/forwarder/Forwarder.sol";

contract CEDAForwarder is Forwarder {
    constructor() Forwarder() {}
}
