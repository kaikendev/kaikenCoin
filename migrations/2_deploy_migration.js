const KaikenToken = artifacts.require('KaikenToken')
const Kaiken = artifacts.require('Kaiken')

module.exports = async function (deployer) {
  await deployer.deploy(KaikenToken, 'Kaiken Coin', 'KAIKEN')
  await deployer.deploy(Kaiken, 'Kaiken Coin', 'KAIKEN')
}
