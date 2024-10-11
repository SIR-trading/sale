const { exec } = require("child_process");
const { ethers } = require("ethers");
require("dotenv").config();

/**
 * Delays execution for a specified number of milliseconds.
 *
 * @param {number} ms - Delay duration in milliseconds.
 * @returns {Promise} - A promise that resolves after the specified delay.
 */
function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Executes a shell command and returns a promise.
 *
 * @param {string} command - The command to execute.
 * @returns {Promise} - A promise that resolves with the command output.
 */
function execCommand(command) {
  return new Promise((resolve, reject) => {
    exec(command, (error, stdout, stderr) => {
      if (error) {
        reject(`Error: ${error.message}`);
        return;
      }
      if (stderr) {
        reject(`stderr: ${stderr}`);
        return;
      }
      resolve(stdout);
    });
  });
}

const rpcUrl = `http://127.0.0.1:${process.env.PORT}`;

/**
 * Impersonates an account and transfers an ERC721 token.
 *
 * @param {string} contractAddress - The address of the ERC721 contract.
 * @param {string} fromAddress - The address of the current owner of the token.
 * @param {string} toAddress - The address of the recipient.
 * @param {number[]} tokenIds - An array of token IDs to transfer.
 * @param {string} rpcUrl - The RPC URL of the Ethereum node.
 */
async function impersonateAndTransferERC721(
  contractAddress,
  fromAddress,
  toAddress,
  tokenIds
) {
  const impersonateCommand = `
        cast rpc anvil_impersonateAccount ${fromAddress} --rpc-url ${rpcUrl}
    `;

  try {
    console.log(`Executing impersonation command: ${impersonateCommand}`);
    const impersonateStdout = await execCommand(impersonateCommand);
    console.log(`Impersonate success: ${impersonateStdout}`);

    for (let tokenId of tokenIds) {
      const transferCommand = `
                cast send ${contractAddress} \
                --from ${fromAddress} \
                "safeTransferFrom(address,address,uint256)" ${fromAddress} ${toAddress} ${tokenId} \
                --rpc-url ${rpcUrl} --unlocked
            `;
      console.log(
        `Executing transfer command for token ID ${tokenId}: ${transferCommand}`
      );
      const transferStdout = await execCommand(transferCommand);
      console.log(
        `Transfer success for token ID ${tokenId}: ${transferStdout}`
      );

      // Delay for 5 seconds between transfers
      await delay(2000);
    }
  } catch (error) {
    console.error(`Error: ${error}`);
  }
}

async function getStablecoin(contractAddress, fromAddress, toAddress, amount) {
  const impersonateCommand = `
        cast rpc anvil_impersonateAccount ${fromAddress} --rpc-url ${rpcUrl}
    `;
  try {
    console.log(`Executing impersonation command: ${impersonateCommand}`);
    const impersonateStdout = await execCommand(impersonateCommand);
    console.log(`Impersonate success: ${impersonateStdout}`);

    const transferCommand = `
            cast send ${contractAddress} \
            --from ${fromAddress} \
            "transfer(address,uint256)" ${toAddress} ${amount} \
            --rpc-url ${rpcUrl} --unlocked
        `;
    console.log(
      `Executing transfer command for ${contractAddress}: ${transferCommand}`
    );
    const transferStdout = await execCommand(transferCommand);
    console.log(
      `Transfer success for contract ${contractAddress}: ${transferStdout}`
    );

    // Delay for 5 seconds between transfers
    await delay(2000);
  } catch (error) {
    console.error(`Error: ${error}`);
  }
}
// Example usage
const buterinCards = {
  contractAddress: "0x5726C14663A1EaD4A7D320E8A653c9710b2A2E89",
  fromAddress: process.env.USER_ADDRESS,
  tokenIds: [1589, 1647, 848],
};

const minedJpegs = {
  contractAddress: "0x7cd51FA7E155805C34F333ba493608742A67Da8e",
  fromAddress: process.env.USER_ADDRESS,
  tokenIds: [30, 29, 27],
};

const usdt = {
  contractAddress: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
  fromAddress: "0xF977814e90dA44bFA03b6295A0616a897441aceC",
  amount: 50000,
};

async function transferEth(fromAddress, privateKey, toAddress, amount) {
  try {
    const transferCommand = `
            cast send ${toAddress} \
            --value ${amount} \
            --from ${fromAddress} \
            --private-key ${privateKey} \
            --rpc-url ${rpcUrl}
        `;

    console.log(`Executing transfer command: ${transferCommand}`);
    const { stdout: transferStdout } = await execCommand(transferCommand);
    console.log(`Transfer success: ${transferStdout}`);

    // Delay for 5 seconds between transfers
    await delay(5000);
  } catch (error) {
    console.error(`Error: ${error}`);
  }
}

// Anvil default account
const ethHolder = {
  address: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
  privateKey:
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
};

const mainModule = async () => {
  await impersonateAndTransferERC721(
    buterinCards.contractAddress,
    buterinCards.fromAddress,
    process.env.USER_ADDRESS,
    buterinCards.tokenIds
  );
  await impersonateAndTransferERC721(
    minedJpegs.contractAddress,
    minedJpegs.fromAddress,
    process.env.USER_ADDRESS,
    minedJpegs.tokenIds
  );
  await getStablecoin(
    usdt.contractAddress,
    usdt.fromAddress,
    process.env.USER_ADDRESS,
    usdt.amount
  );
  await transferEth(
    ethHolder.address,
    ethHolder.privateKey,
    process.env.USER_ADDRESS,
    ethers.parseEther("10")
  );

  process.exit(0);
};

mainModule();
