// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;


contract SurrogateProposal {
    bool isActive;
    uint createdAt;
    uint resolutionAt;
    mapping(address => address) votes;
    address winner;

  constructor() {
    isActive = true;
    createdAt = block.timestamp;
    resolutionAt = block.timestamp + 30 days;
    
  }
}

