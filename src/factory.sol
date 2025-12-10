// SPDX-License Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ExchangeV1} from "./uniswap_v1.sol";

contract Factory {
    //  token   =>   exchange address
    mapping(address => address) public exchanges;
    // exchange =>  token address !
    mapping(address => address) public tokens;

    event PairCreated(address indexed _token, address exchanges, uint256 timestamp);

    function create_exchange(address _token, uint256 _amount) external payable returns (address) {
        require(_token != address(0), "Zero_Address");
        require(_amount != 0, "Zero_Amount");
        require(exchanges[_token] == address(0), "Already_pair_exist");

        ExchangeV1 exchange = new ExchangeV1(_token);

        exchanges[_token] = address(exchange);
        tokens[address(exchange)] = _token;

        emit PairCreated(_token, address(exchange), block.timestamp);

        return address(exchange);
    }

    function get_exchange(address _token) public view returns (address) {
        require(_token != address(0), "Zero_token_address");

        return exchanges[_token];
    }

    function get_token(address _exchange) public view returns (address) {
        require(_exchange != address(0), "Zero_address_exchange");

        return tokens[_exchange];
    }
}
