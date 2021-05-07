usePlugin('@nomiclabs/buidler-truffle5');
usePlugin('@nomiclabs/buidler-web3');
usePlugin('buidler-contract-sizer');

// You have to export an object to set up your config
// This object can have the following optional entries:
// defaultNetwork, networks, solc, and paths.
// Go to https://buidler.dev/config/ to learn more
module.exports = {
  defaultNetwork: 'buidlerevm',
  // This is a sample solc configuration that specifies which version of solc to use
  solc: {
    version: '0.6.6', // Fetch exact version from solc-bin (default: truffle's version)
    // See the solidity docs for advice about optimization and evmVersion
    optimizer: {
      enabled: true,
      runs: 200
    }
  }
};
