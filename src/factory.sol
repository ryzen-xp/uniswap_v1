// SPDX-License Identifier: UNLICENSED

pragma solidity ^0.8.13;

contract Factory {
    //  token   =>   exchange address
    mapping(address => address) public exchanges;

    function createPair(address _tokenA) public {}
}
