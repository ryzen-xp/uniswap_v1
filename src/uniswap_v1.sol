// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/// @title Exchange contract for Uniswap V1 (Simplified)
/// @author @ryzen_xp
contract ExchangeV1 is ERC20 {
    ////////////// STATE VARIABLE ////////////

    address public immutable TOKEN_ADDRESS;
    address public immutable FACTORY_ADDRESS;
    IERC20 public immutable TOKEN;

    uint256 public constant FEE = 3;

    uint256 public totalLiquidity;
    mapping(address => uint256) public lpBalance;

    ///////////////////////// ERRORS ////////////////////////

    error DeadlineExpired(uint256 provided, uint256 current);
    error ZeroMaxToken();
    error InvalidEthAmount();
    error ZeroMinLiquidity();
    error NotMatchYourRequirement();
    error FailedToTransferToken();
    error InvalidFactoryAddress();
    error InvalidTokenAddress();
    error InvalidInput();
    error ZeroLiquidity();
    error InsufficentBalance();
    error FailedToTransferETH();

    //////////////////////// EVENTS ///////////////////////
    event AddLiquidity(address indexed provider, uint256 ethAmount, uint256 tokenAmount);
    event RemovedLiquidity(address indexed recipient, uint256 eth_amount, uint256 token_amount);
    event ETHToToken(address indexed recipient, uint256 ethAmount, uint256 tokenAmount, uint256 timestamp);

    constructor(address _tokenAddress) ERC20("LP TOKEN", "XP") {
        if (_tokenAddress == address(0)) revert InvalidTokenAddress();
        TOKEN_ADDRESS = _tokenAddress;
        TOKEN = IERC20(TOKEN_ADDRESS);
        FACTORY_ADDRESS = msg.sender;
    }

    ///////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////// Liquidity Functions //////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////

    /// @notice Add liquidity (ETH + TOKEN)
    function addLiquidity(uint256 minLiquidity, uint256 maxToken, uint256 deadline) external payable returns (uint256) {
        if (deadline < block.timestamp) revert DeadlineExpired(deadline, block.timestamp);
        if (maxToken == 0) revert ZeroMaxToken();
        if (msg.value == 0) revert InvalidEthAmount();

        uint256 _totalLiquidity = totalLiquidity;

        /// ------------------ EXISTING LIQUIDITY ------------------
        if (_totalLiquidity > 0) {
            if (minLiquidity > 0) revert ZeroMinLiquidity();

            uint256 ethReserve = address(this).balance - msg.value;
            uint256 tokenReserve = TOKEN.balanceOf(address(this));

            uint256 tokenAmount = (msg.value * tokenReserve) / ethReserve;
            uint256 liquidityMinted = (msg.value * _totalLiquidity) / ethReserve;

            if (maxToken < tokenAmount || liquidityMinted < minLiquidity) {
                revert NotMatchYourRequirement();
            }

            lpBalance[msg.sender] += liquidityMinted;
            totalLiquidity = _totalLiquidity + liquidityMinted;

            if (!TOKEN.transferFrom(msg.sender, address(this), tokenAmount)) revert FailedToTransferToken();

            _mint(msg.sender, liquidityMinted);

            emit AddLiquidity(msg.sender, msg.value, tokenAmount);
            return liquidityMinted;
        }
        /// ------------------ FIRST TIME LIQUIDITY ------------------
        else {
            if (FACTORY_ADDRESS == address(0)) revert InvalidFactoryAddress();

            uint256 tokenAmount = maxToken;
            uint256 initialLiquidity = msg.value;

            totalLiquidity = initialLiquidity;
            lpBalance[msg.sender] = initialLiquidity;

            if (!TOKEN.transferFrom(msg.sender, address(this), tokenAmount)) revert FailedToTransferToken();

            _mint(msg.sender, initialLiquidity);

            emit AddLiquidity(msg.sender, initialLiquidity, tokenAmount);

            return initialLiquidity;
        }
    }
    // removeLiquidity ( amount  , min_eth , min_TOKEN ,  deadline )

    function removeLiquidity(uint256 amount, uint256 min_eth, uint256 min_token, uint256 deadline)
        external
        returns (uint256, uint256)
    {
        if (amount == 0 || min_eth == 0 || min_token == 0 || deadline <= block.timestamp) {
            revert InvalidInput();
        }

        if (totalLiquidity == 0) {
            revert ZeroLiquidity();
        }
        if (lpBalance[msg.sender] < amount) {
            revert InsufficentBalance();
        }

        uint256 token_reserve = TOKEN.balanceOf(address(this));
        uint256 eth_reserve = address(this).balance;

        uint256 eth_amount = amount * eth_reserve / totalLiquidity;
        uint256 token_amount = amount * token_reserve / totalLiquidity;

        if (eth_amount < min_eth || token_amount < min_token) {
            revert NotMatchYourRequirement();
        }

        lpBalance[msg.sender] -= amount;

        totalLiquidity -= amount;

        (bool success,) = payable(msg.sender).call{value: eth_amount}("");
        if (!success) revert FailedToTransferETH();

        if (!TOKEN.transfer(msg.sender, token_amount)) {
            revert FailedToTransferToken();
        }

        emit RemovedLiquidity(msg.sender, eth_amount, token_amount);
        return (eth_amount, token_amount);
    }

    ///////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////// Swapper Functions ////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////

    // ethToTOKENSwap(min_TOKENs, recipient address, deadline)
    function ETHToTokenSwap(uint256 min_token, address recipient, uint256 deadline) external payable returns (uint256) {
        if (min_token == 0 || recipient == address(0) || deadline < block.timestamp) {
            revert InvalidInput();
        }
        if (msg.value == 0) {
            revert InvalidEthAmount();
        }
        uint256 eth_reserve = address(this).balance - msg.value;
        uint256 token_reserve = getTokenReserve();

        uint256 tokenBought = getAmount(msg.value, eth_reserve, token_reserve);

        if (tokenBought < min_token) {
            revert NotMatchYourRequirement();
        }

        TOKEN.transfer(msg.sender, tokenBought);

        emit ETHToToken(msg.sender, msg.value, tokenBought, block.timestamp);

        return tokenBought;
    }

    // TOKENToEthSwap(TOKEN_amount_in, min_eth_out, recipient, deadline)
    function TokenToETHSwap(uint256 token_amount, uint256 min_eth_out, address recipient, uint256 deadline)
        external
        returns (uint256)
    {
        if (token_amount == 0 || recipient == address(0) || deadline < block.timestamp) {
            revert InvalidInput();
        }

        uint256 token_reserve = getTokenReserve();
        uint256 eth_reserve = address(this).balance;

        uint256 eth_bought = getAmount(token_amount, token_reserve, eth_reserve);

        if (eth_bought < min_eth_out) {
            revert NotMatchYourRequirement();
        }

        (bool status,) = address(this).call{value: eth_bought}("");

        if (!status) {
            revert FailedToTransferETH();
        }

        emit ETHToToken(msg.sender, token_amount, eth_bought, block.timestamp);
        return eth_bought;
    }

    ///////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////// Getter Functions /////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////

    //  getInputPrice(input  , input_reserves ,  outputReserves)
    function getInputAmount(uint256 output_amount, uint256 input_reserve, uint256 output_reserve)
        private
        pure
        returns (uint256)
    {
        if (output_amount == 0 || input_reserve == 0 || output_reserve == 0 || output_amount >= output_reserve) {
            revert InvalidInput();
        }

        uint256 numerator = input_reserve * output_amount * 1000;
        uint256 denominator = (output_reserve - output_amount) * 997;
        return (numerator / denominator) + 1;
    }

    //  getOutputPrice(output , inputPrice ,OutputReserves)
    function getOutputAmount(uint256 input_amount, uint256 input_reserve, uint256 output_reserve)
        private
        pure
        returns (uint256)
    {
        if (input_amount == 0 || input_reserve == 0 || output_reserve == 0) {
            revert InvalidInput();
        }

        uint256 input_amount_with_fee = input_amount * 997;
        uint256 numerator = input_amount_with_fee * output_reserve;
        uint256 denominator = (input_reserve * 1000) + input_amount_with_fee;

        return numerator / denominator;
    }

    //  get reserves of exchange pair
    function getTokenReserve() public view returns (uint256) {
        return TOKEN.balanceOf(address(this));
    }

    //  getPrice

    function getAmount(uint256 input_amount, uint256 input_reserve, uint256 output_reserve)
        private
        pure
        returns (uint256)
    {
        if (input_amount == 0 || input_reserve == 0 || output_reserve == 0) {
            revert InvalidInput();
        }

        uint256 input_amount_withFee = input_amount * 997;
        uint256 n = input_amount_withFee * output_reserve;
        uint256 d = (input_reserve * 1000) + input_amount_withFee;

        return n / d;
    }

    // get token amount

    function getTokenAmount(uint256 eth_amount) public view returns (uint256) {
        if (eth_amount == 0) {
            revert InvalidInput();
        }

        return getAmount(eth_amount, address(this).balance, getTokenReserve());
    }

    //  getETHAMoubt

    function getETHAmount(uint256 token_amount) public view returns (uint256) {
        if (token_amount == 0) {
            revert InvalidInput();
        }

        return getAmount(token_amount, getTokenReserve(), address(this).balance);
    }
}

