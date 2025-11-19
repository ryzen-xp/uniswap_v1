// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {ExchangeV1} from "../src/uniswap_v1.sol";
import {Token} from "../src/token.sol";

contract ExchangeTest is Test {
    address BOB = makeAddr("BOB");

    ExchangeV1 exchange;
    Token token;

    function setUp() public {
        token = new Token();
        exchange = new ExchangeV1(address(token));
    }

    /// ---------------------------------------------------------
    ///                 Add Liquidity Test
    /// ---------------------------------------------------------

    function test_addLiquidity_successful() external {
        uint256 mintAmount = 10_000 ether;
        uint256 maxToken = 1000 ether;
        uint256 minLiquidity = 1000 wei;
        uint256 deadline = block.timestamp + 100;

        // Mint tokens to BOB
        token.mint(BOB, mintAmount);

        vm.deal(BOB , mintAmount);

        vm.startPrank(BOB);

        // Approve the exchange to spend BOB's tokens
        token.approve(address(exchange), type(uint256).max);

        // Add liquidity (BOB sends 1 ETH)
        uint256 liquidity = exchange.addLiquidity{value: 1 ether}(minLiquidity, maxToken, deadline);

        vm.stopPrank();

        // Assertions
        assertEq(liquidity, 1 ether, "Initial liquidity should equal ETH deposited");
        assertEq(exchange.totalLiquidity(), 1 ether, "Total liquidity updated");
        assertEq(exchange.balanceOf(BOB), 1 ether, "LP tokens were minted to BOB");
        assertEq(token.balanceOf(address(exchange)), maxToken, "Token reserve updated");
    }
}
