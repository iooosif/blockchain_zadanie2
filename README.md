# blockchain_zadanie2
Launch instruction:
reinstall project dependencies
rm -rf node_modules package-lock.json
npm install

Compile the contract
npx hardhat compile

load node
npx hardhat node   

Update ABI

Deploy contracts in another terminal window
npx hardhat run --network localhost scripts/deploy_token.js
npx hardhat run --network localhost scripts/deploy_exchange.js

Update exchange_address and token_address in exchange.js

open index.html in browser.

At the moment, the basic setup has been done, creating your own token, setting up a simple exchange, functions addLiquidity(), removeLiquidity, removeAllLiquidity(), swapTokensForETH, swapETHForTokens() in solidity and js. Implemented actions with deviation from the course, passed sanity check.
