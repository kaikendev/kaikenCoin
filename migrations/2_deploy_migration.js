const KaikenToken = artifacts.require('KaikenToken')

module.exports = async function (deployer) {
  await deployer.deploy(KaikenToken, 'Kaiken Coin', 'KAIKEN')
}
