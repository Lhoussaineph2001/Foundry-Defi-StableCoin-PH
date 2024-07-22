//SPDX-License-Identifier:MIT

pragma solidity ^0.8.0;

import { AggregatorV3Interface } from '@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol';

library  OracleLib {

    error OracleLib__StalePrice();

    uint256 private constant TIMEOUT = 3  hours ; 

    function staleChecklatestRoundData(AggregatorV3Interface priceFeed) public view  returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
 
     {
    
    ( roundId, answer,  startedAt,  updatedAt,  answeredInRound) = priceFeed.latestRoundData();

    uint256 secondsSince = block.timestamp - updatedAt;

    if ( secondsSince > TIMEOUT){

        revert OracleLib__StalePrice();

    }

    return ( roundId, answer,  startedAt,  updatedAt,  answeredInRound) ;

    } 

}