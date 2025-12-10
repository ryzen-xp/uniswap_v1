// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {ExchangeV1} from "../src/uniswap_v1.sol";
import {Token} from "../src/token.sol";
import {Factory} from "../src/factory.sol";

contract ExchangeTest is Test {
    address BOB = makeAddr("BOB");
    address Alice = makeAddr("alice");

    Token token;
    Factory factory;

    function setUp() public {
        token = new Token();

        factory = new Factory();
    }

    function test_create_exchange() external {}
}
