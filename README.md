# ERC721 Token Transfer Script

This project contains a Node.js script to impersonate an account and transfer multiple ERC721 tokens from one address to another, with a delay between each transfer. The script uses `fork` commands for impersonation and token transfer.

## Requirements

- Node.js (v12 or higher)
- Installed `cast` tool for executing RPC commands with Fork (e.g., Hardhat network or a similar environment)

## Script Overview

The script performs the following operations:

1. Impersonates a given account.
2. Transfers specified ERC721 tokens from the impersonated account to another account.
3. Introduces a delay between each token transfer.

## Setup

1. Clone the repository:

   ```sh
   git clone <repository_url>
   cd <repository_directory>
   ```

2. Install dependencies (if any needed for your development environment):

   ```sh
   npm install
   ```

3. Ensure you have the necessary tools installed for running `cast` commands.

## Usage

Update the .env file with the correct values for your project:

- `USER_ADDRESS`: the address you control
- `PORT`: the port for the local forket chain.

### Example

The script is configured to transfer Mined JPEG and Buterin Cards NFTS from NFT_HOLDER to USER_ADDRESS for the purpose of testing.

To start the forked network, use the following command:

```sh
npm run deploy
```

To run the script and execute the token transfers, use the following command:

```sh
npm run transfer
```

## Notes

- Ensure you have a proper development environment set up for running and impersonating accounts with the `fork` tool.
- Adjust the delay duration as per your requirements by changing the value in the `await delay(2000);` statement (it is set to 2 seconds in this example).
