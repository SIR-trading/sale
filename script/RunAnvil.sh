# Load the environment variables
source .env

# Run the Anvil server
anvil  -p $PORT --fork-url "https://eth-mainnet.g.alchemy.com/v2/${ALCHEMY_APIKEY}" --fork-block-number 20944804 &
ANVIL_PID=$!

# Impersonate automatically
cast rpc anvil_autoImpersonateAccount true --rpc-url "http://localhost:${PORT}"

# Send a bunch of Buterin Cards to the user
buterinCardsAddress="0x5726C14663A1EaD4A7D320E8A653c9710b2A2E89"
cast send $buterinCardsAddress --from $NFT_HOLDER "safeTransferFrom(address,address,uint256)" $NFT_HOLDER $USER_ADDRESS 0 --rpc-url "http://localhost:${PORT}" --unlocked
cast send $buterinCardsAddress --from $NFT_HOLDER "safeTransferFrom(address,address,uint256)" $NFT_HOLDER $USER_ADDRESS 399 --rpc-url "http://localhost:${PORT}" --unlocked
cast send $buterinCardsAddress --from $NFT_HOLDER "safeTransferFrom(address,address,uint256)" $NFT_HOLDER $USER_ADDRESS 623 --rpc-url "http://localhost:${PORT}" --unlocked
cast send $buterinCardsAddress --from $NFT_HOLDER "safeTransferFrom(address,address,uint256)" $NFT_HOLDER $USER_ADDRESS 820 --rpc-url "http://localhost:${PORT}" --unlocked
cast send $buterinCardsAddress --from $NFT_HOLDER "safeTransferFrom(address,address,uint256)" $NFT_HOLDER $USER_ADDRESS 1596 --rpc-url "http://localhost:${PORT}" --unlocked
cast send $buterinCardsAddress --from $NFT_HOLDER "safeTransferFrom(address,address,uint256)" $NFT_HOLDER $USER_ADDRESS 2007 --rpc-url "http://localhost:${PORT}" --unlocked

# Send a bunch of Mined JPEGs to the user
minedJpegsAddress="0x7cd51FA7E155805C34F333ba493608742A67Da8e"
cast send $minedJpegsAddress --from $NFT_HOLDER "safeTransferFrom(address,address,uint256)" $NFT_HOLDER $USER_ADDRESS 26 --rpc-url "http://localhost:${PORT}" --unlocked
cast send $minedJpegsAddress --from $NFT_HOLDER "safeTransferFrom(address,address,uint256)" $NFT_HOLDER $USER_ADDRESS 27 --rpc-url "http://localhost:${PORT}" --unlocked
cast send $minedJpegsAddress --from $NFT_HOLDER "safeTransferFrom(address,address,uint256)" $NFT_HOLDER $USER_ADDRESS 29 --rpc-url "http://localhost:${PORT}" --unlocked
cast send $minedJpegsAddress --from $NFT_HOLDER "safeTransferFrom(address,address,uint256)" $NFT_HOLDER $USER_ADDRESS 30 --rpc-url "http://localhost:${PORT}" --unlocked

# Send 1M USDT, USDC, and DAI to the user
stablecoinRichieAddress="0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7"
cast rpc anvil_setBalance $stablecoinRichieAddress 0xFFFFFFFFFFFFFFFF --rpc-url "http://localhost:${PORT}"
cast send "0xdAC17F958D2ee523a2206206994597C13D831ec7" --from $stablecoinRichieAddress "transfer(address,uint256)" $USER_ADDRESS \
    1000000000000 --rpc-url "http://localhost:${PORT}" --unlocked # USDT
cast send "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" --from $stablecoinRichieAddress "transfer(address,uint256)" $USER_ADDRESS \
    1000000000000 --rpc-url "http://localhost:${PORT}" --unlocked # USDC
cast send "0x6B175474E89094C44Da98b954EedeAC495271d0F" --from $stablecoinRichieAddress "transfer(address,uint256)" $USER_ADDRESS \
    1000000000000000000000000 --rpc-url "http://localhost:${PORT}" --unlocked # DAI

# Transfer ETH to the user
cast rpc anvil_setBalance $USER_ADDRESS 0xFFFFFFFFFFFFFFFF --rpc-url "http://localhost:${PORT}"

# Wait for the Anvil process to terminate
echo "Initialization complete! Anvil running on port $PORT".
wait $ANVIL_PID