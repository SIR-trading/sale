require("dotenv").config();

const { exec } = require("child_process");

// Construct the RPC URL using the environment variable
const forkUrl = `https://eth-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_APIKEY}`;

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
      console.log(stdout);

      resolve(stdout);
    });
  });
}

const rpcEndpoint = `http://127.0.0.1:${process.env.PORT}`;
const command = `anvil --fork-url ${forkUrl}`;

const mainModule = async () => {
  try {
    console.log("Anvil network starting with endpoint: ", rpcEndpoint);
    const anvil = await execCommand(command);
    console.log(anvil);
  } catch (error) {
    console.error("Error:", error);
  }
};

mainModule();
