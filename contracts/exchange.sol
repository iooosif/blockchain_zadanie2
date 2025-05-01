// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;


import './token.sol';
import "hardhat/console.sol";


contract TokenExchange is Ownable {
    string public exchange_name = 'FIITchange';

    address tokenAddr= 0x5FbDB2315678afecb367f032d93F642f64180aa3;                               // TODO: paste token contract address here
    Token public token = Token(tokenAddr);                                

    // Liquidity pool for the exchange
    uint private token_reserves = 0;
    uint private eth_reserves = 0;

    mapping(address => uint) private lps; 
     
    // Needed for looping through the keys of the lps mapping
    address[] private lp_providers;                     

    // liquidity rewards
    uint private swap_fee_numerator = 3;                
    uint private swap_fee_denominator = 100;

    // Constant: x * y = k
    uint private k;

    constructor() {}
    

    // Function createPool: Initializes a liquidity pool between your Token and ETH.
    // ETH will be sent to pool in this transaction as msg.value
    // amountTokens specifies the amount of tokens to transfer from the liquidity provider.
    // Sets up the initial exchange rate for the pool by setting amount of token and amount of ETH.
    function createPool(uint amountTokens)
        external
        payable
        onlyOwner
    {
        // This function is already implemented for you; no changes needed.

        // require pool does not yet exist:
        require (token_reserves == 0, "Token reserves was not 0");
        require (eth_reserves == 0, "ETH reserves was not 0.");

        // require nonzero values were sent
        require (msg.value > 0, "Need eth to create pool.");
        uint tokenSupply = token.balanceOf(msg.sender);
        require(amountTokens <= tokenSupply, "Not have enough tokens to create the pool");
        require (amountTokens > 0, "Need tokens to create pool.");

        token.transferFrom(msg.sender, address(this), amountTokens);
        token_reserves = token.balanceOf(address(this));
        eth_reserves = msg.value;
        k = token_reserves * eth_reserves;
    }

    // Function removeLP: removes a liquidity provider from the list.
    // This function also removes the gap left over from simply running "delete".
    function removeLP(uint index) private {
        require(index < lp_providers.length, "specified index is larger than the number of lps");
        lp_providers[index] = lp_providers[lp_providers.length - 1];
        lp_providers.pop();
    }

    // Function getSwapFee: Returns the current swap fee ratio to the client.
    function getSwapFee() public view returns (uint, uint) {
        return (swap_fee_numerator, swap_fee_denominator);
    }
// ============================================================
    //                    FUNCTIONS TO IMPLEMENT
    // ============================================================

    /* ========================= Liquidity Provider Functions ========================= */

    // Function addLiquidity: Adds liquidity given a supply of ETH (sent to the contract as msg.value in ETH).
    function addLiquidity(uint max_exchange_rate, uint min_exchange_rate) external payable {
    console.log("Sender ETH balance at start (wei):", msg.sender.balance);
    console.log("addLiquidity: msg.value (ETH in wei) =", msg.value);
    require(msg.value > 0, "Need ETH to add liquidity");
    console.log("addLiquidity: token_reserves (PRMT) =", token_reserves, "eth_reserves (ETH) =", eth_reserves);
    require(token_reserves > 0 && eth_reserves > 0, "Pool not initialized");

    uint current_exchange_rate = (token_reserves * 1000) / eth_reserves;
    console.log("addLiquidity: current_exchange_rate (PRMT per ETH, scaled by 1000) =", current_exchange_rate);
    console.log("addLiquidity: max_exchange_rate =", max_exchange_rate);
    console.log("addLiquidity: min_exchange_rate =", min_exchange_rate);
    require(current_exchange_rate <= max_exchange_rate, "Slippage too high: exchange rate above maximum");
    require(current_exchange_rate >= min_exchange_rate, "Slippage too low: exchange rate below minimum");

    uint tokenAmount = (msg.value * token_reserves) / eth_reserves;
    console.log("addLiquidity: tokenAmount (PRMT) =", tokenAmount);
    uint senderBalance = token.balanceOf(msg.sender);
    console.log("addLiquidity: sender token balance (PRMT) =", senderBalance);
    require(senderBalance >= tokenAmount, "Insufficient token balance");

    console.log("addLiquidity: calling transferFrom");
    token.transferFrom(msg.sender, address(this), tokenAmount);

    token_reserves += tokenAmount;
    eth_reserves += msg.value;
 
    console.log("k before:", k);
    k = token_reserves * eth_reserves;
    console.log("k after:", k);

    if (lps[msg.sender] == 0) {
        lp_providers.push(msg.sender);
    }
    lps[msg.sender] += msg.value;
    console.log("addLiquidity: completed successfully");
    console.log("Sender ETH balance at end (wei):", msg.sender.balance);
}

    // Function removeLiquidity: Removes liquidity given the desired amount of ETH to remove (in ETH).
    function removeLiquidity(uint amountETH, uint max_exchange_rate, uint min_exchange_rate)
        public
        payable
    {
        require(amountETH > 0, "Amount must be greater than 0");
        require(amountETH <= eth_reserves - 1, "Not enough ETH in reserves");
        require(amountETH <= lps[msg.sender], "Not enough liquidity provided by sender");

        // Проверка текущего курса обмена (PRMT за 1 ETH)
        uint current_exchange_rate = (token_reserves * 1000) / eth_reserves; // Умножаем на 1000 для точности
        require(current_exchange_rate <= max_exchange_rate, "Slippage too high: exchange rate above maximum");
        require(current_exchange_rate >= min_exchange_rate, "Slippage too low: exchange rate below minimum");

        uint amountTokens = (amountETH * token_reserves) / eth_reserves;
        require(amountTokens <= token_reserves - 1, "Not enough tokens in reserves");

        // Update reserves
        token_reserves -= amountTokens;
        eth_reserves -= amountETH;
        console.log("k before:", k);
        k = token_reserves * eth_reserves;
        console.log("k after:", k);

        // Update liquidity provider's contribution
        lps[msg.sender] -= amountETH;
        if (lps[msg.sender] == 0) {
            for (uint i = 0; i < lp_providers.length; i++) {
                if (lp_providers[i] == msg.sender) {
                    removeLP(i);
                    break;
                }
            }
        }

        // Transfer tokens and ETH back to sender
        token.transfer(msg.sender, amountTokens);
        payable(msg.sender).transfer(amountETH);
    }

    // Function removeAllLiquidity: Removes all liquidity that msg.sender is entitled to withdraw
    function removeAllLiquidity(uint max_exchange_rate, uint min_exchange_rate)
        external
        payable
    {
        require(lps[msg.sender] > 0, "No liquidity to remove");

        // Проверка текущего курса обмена (PRMT за 1 ETH)
        uint current_exchange_rate = (token_reserves * 1000) / eth_reserves; // Умножаем на 1000 для точности
        require(current_exchange_rate <= max_exchange_rate, "Slippage too high: exchange rate above maximum");
        require(current_exchange_rate >= min_exchange_rate, "Slippage too low: exchange rate below minimum");

        uint amountETH = lps[msg.sender];
        uint amountTokens = (amountETH * token_reserves) / eth_reserves;

        require(amountETH <= eth_reserves - 1, "Not enough ETH in reserves");
        require(amountTokens <= token_reserves - 1, "Not enough tokens in reserves");

        // Update reserves
        token_reserves -= amountTokens;
        eth_reserves -= amountETH;
        console.log("k before:", k);
        k = token_reserves * eth_reserves;
        console.log("k after:", k);

        // Remove sender from liquidity providers
        for (uint i = 0; i < lp_providers.length; i++) {
            if (lp_providers[i] == msg.sender) {
                removeLP(i);
                break;
            }
        }
        lps[msg.sender] = 0;

        // Transfer tokens and ETH back to sender
        token.transfer(msg.sender, amountTokens);
        payable(msg.sender).transfer(amountETH);
    }

    /***  Define additional functions for liquidity fees here as needed ***/
    // Function getReserves: Returns the current reserves of the pool
    function getReserves() public view returns (uint, uint) {
        return (token_reserves, eth_reserves);
    }

    /* ========================= Swap Functions ========================= */

    // Function swapTokensForETH: Swaps your token with ETH (amountTokens in PRMT)
    function swapTokensForETH(uint amountTokens, uint min_exchange_rate)
        external
        payable
    {
        require(amountTokens > 0, "Must send tokens to swap");
        require(amountTokens <= token_reserves - 1, "Not enough tokens in reserves");

        uint amountETH = (amountTokens * eth_reserves) / token_reserves;
        require(amountETH <= eth_reserves - 1, "Not enough ETH in reserves");

        // Apply swap fee
        uint fee = (amountETH * swap_fee_numerator) / swap_fee_denominator;
        amountETH -= fee;

        // Проверка текущего курса обмена (ETH за 1 PRMT)
        uint current_exchange_rate = (amountETH * 1000) / amountTokens; // Умножаем на 1000 для точности
        require(current_exchange_rate >= min_exchange_rate, "Slippage too high: exchange rate below minimum");

        // Transfer tokens from sender to contract
        token.transferFrom(msg.sender, address(this), amountTokens);

        // Update reserves
        token_reserves += amountTokens;
        eth_reserves -= amountETH;
        console.log("k before:", k);
        k = token_reserves * eth_reserves;
        console.log("k after:", k);

        // Transfer ETH to sender
        payable(msg.sender).transfer(amountETH);
    }

    // Function swapETHForTokens: Swaps ETH for your tokens (msg.value in ETH)
    function swapETHForTokens(uint min_exchange_rate)
        external
        payable
    {
        require(msg.value > 0, "Must send ETH to swap");
        require(eth_reserves > 0, "Pool not initialized");

        uint amountTokens = (msg.value * token_reserves) / eth_reserves;
        require(amountTokens <= token_reserves - 1, "Not enough tokens in reserves");

        // Apply swap fee
        uint fee = (amountTokens * swap_fee_numerator) / swap_fee_denominator;
        amountTokens -= fee;

        // Проверка текущего курса обмена (PRMT за 1 ETH)
        uint current_exchange_rate = (amountTokens * 1000) / msg.value; // Умножаем на 1000 для точности
        require(current_exchange_rate >= min_exchange_rate, "Slippage too high: exchange rate below minimum");

        // Update reserves
        token_reserves -= amountTokens;
        eth_reserves += msg.value;
        console.log("k before:", k);
        k = token_reserves * eth_reserves;
        console.log("k after:", k);

        // Transfer tokens to sender
        token.transfer(msg.sender, amountTokens);
    

}}