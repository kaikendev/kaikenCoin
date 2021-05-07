// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract KaikenToken is ERC20 {
    using SafeMath for uint;

    uint private constant BPS = 100;
    address _kaikenReserveAddr = 0x3FEE83b4a47D4D6425319A09b91C0559DDF9E31C; // My Sola ETH Account

    constructor(
        string memory _name,
        string memory _symbol
    ) public ERC20(_name, _symbol) {
        _mint(msg.sender, 100000000000 * (10 ** uint256(decimals())));
    }

    event GotTax(address msgSender, uint sentAmount, uint balanceOfSender, uint percentageTransferred , uint taxPercentage);

    function getReserveAddress() public view returns(address) {
        return _kaikenReserveAddr;
    }
    function getBalance(address addr) public view returns(uint256) {
        return balanceOf(addr);
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        (, uint taxAmount) = _getReceivedAmount(msg.sender, spender, amount);
        return super.approve(spender, amount.add(taxAmount));
    }

    function transferFrom(
        address from,
        address to,
        uint amount
    ) public virtual override returns (bool success) {
        return _transferFrom(from, to, amount);
    }

    function _getReceivedAmount(
        address _from,
        address, /*_to*/
        uint _sentAmount
    ) internal returns (uint receivedAmount, uint taxAmount) {
        uint taxPercentage = _getTaxPercentage(_from, _sentAmount);
        receivedAmount = _sentAmount.sub(_sentAmount.div(BPS).mul(taxPercentage));
        taxAmount = _sentAmount.sub(receivedAmount);
    }

    function _transferFrom(
        address _from,
        address _to,
        uint _amount
    ) internal returns (bool success){
        (, uint taxAmount) = _getReceivedAmount(_from, _to, _amount);
        bool transferred = super.transferFrom(_from, _kaikenReserveAddr, taxAmount);
        
        if(transferred == true) {
            return super.transferFrom(
                _from, 
                _to, 
                _amount
            );
        }
    }

    function _getTaxPercentage(
        address _from,
        uint _sentAmount
    ) public returns (uint tax) {
        uint taxPercentage;
        uint balanceOfSender = balanceOf(_from);

        require(
            balanceOfSender > 0 && _sentAmount > 0,
            'Intangible balance or amount to send'
        );

        uint percentageTransferred = _sentAmount.mul(100).div(balanceOfSender);

        if (percentageTransferred <= 5) {
            taxPercentage = 8;
        }else if (percentageTransferred <= 10) {
            taxPercentage = 12;
        }else if (percentageTransferred <= 20) {
            taxPercentage = 20;
        }else if (percentageTransferred <= 30) {
            taxPercentage = 30;
        }else if (percentageTransferred <= 50) {
            taxPercentage = 40;
        } else {
            taxPercentage = 90;
        }

        emit GotTax(_from, _sentAmount, balanceOfSender, percentageTransferred, taxPercentage);
        return taxPercentage;
    }
}
