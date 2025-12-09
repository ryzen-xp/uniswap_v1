// SPDX-License Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ExchangeV1} from "./uniswap_v1.sol";

contract Factory  {
    //  token   =>   exchange address
    mapping(address => address) public exchanges;


    event PairCreated(address indexed _token  , address  exchanges  , uint256  timestamp);

    function create_pair(address _token , uint256 _amount) payable external {
        require(_token != address(0) , "Zero_Address");
        require(_amount != 0 , "Zero_Amount");
        require(exchanges[_token] == address(0) ,"Already_pair_exist" );


        ExchangeV1 exchange = new ExchangeV1(_token);

        exchanges[_token] = address(exchange);

        

        emit PairCreated(_token , address(exchange) , block.timestamp);

    }
}
