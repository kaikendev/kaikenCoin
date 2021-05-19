// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract KaikenToken is ERC20 {
    using SafeMath for uint;

    address owner;
    address private reserve = 0x3FEE83b4a47D4D6425319A09b91C0559DDF9E31C; //0xFe76451745386702e091113170b703096dC9E024;

    uint transferMode;
    uint[] startingTaxes = [
        5,
        10,
        15,
        20,
        30,
        45
    ];

     uint[] thresholds = [
        10,
        20,
        30,
        40,
        50
    ];

    //structs 
    struct TaxRecord {
        uint timestamp;
        uint tax;
        uint balance;
    }

    // constants 
    uint private constant BPS = 100;
    uint private constant TOTAL_SUPPLY = 100000000000;
    uint private constant TRANSFER = 0;
    uint private constant TRANSFER_FROM = 1;

    // mappings
    mapping(address => bool) exempts;
    mapping(address => TaxRecord[]) genesis;
    mapping(address => TaxRecord[]) sandboxGenesis;

    //modifiers
    modifier onlyOwner {
        require(msg.sender == owner, 'Only the owner can invoke this call.');
        _;
    }
    // events
    event AddedExempt(address exempted);
    event RemovedExempt(address exempted);
    event UpdatedExempt(address exempted, bool isValid);
    event UpdatedReserve(address reserve);
    event TaxRecordSet(address _addr, uint timestamp, uint balance, uint tax);
    event UpdatedStartingTaxes(uint[] startingTaxes);
    event UpdatedThresholds(uint[] thresholds);
    event InitializedExempts(uint initialized);
    event GotTax(address msgSender, uint sentAmount, uint balanceOfSenderOrFrom, uint percentageTransferred , uint taxPercentage);

    // sandbox events
    event SandboxTaxRecordSet(address addr, uint timestamp, uint balance, uint tax);

    constructor(
        string memory _name,
        string memory _symbol
    ) public ERC20(_name, _symbol) {
        owner = msg.sender;
        _mint(owner, TOTAL_SUPPLY * (10 ** uint256(decimals())));
        _initializeExempts();
    }

    // Overrides
    function transfer(
        address to,
        uint amount
    ) public virtual override returns(bool){
        transferMode = TRANSFER;
        return _internalTransfer(msg.sender, to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint amount
    ) public virtual override returns (bool success) {
        transferMode = TRANSFER_FROM;
        return _internalTransfer(from, to, amount);
    }

    // Reads
    function getStartingTaxes() public view returns(uint[] memory) {
        return startingTaxes;
    }

    function getThresholds() public view returns(uint[] memory){
        return thresholds;
    }

    function getExempt(address _addr) public view returns(bool){
        return exempts[_addr];
    }

    function getReserve() public view returns(address) {
        return reserve;
    }

    // Writes
    function updateStartingTaxes(uint[] memory _startingTaxes) public onlyOwner {
        startingTaxes = _startingTaxes;
        emit UpdatedStartingTaxes(startingTaxes);
    }

    function updateThresholds(uint[] memory _thresholds) public onlyOwner {
        thresholds = _thresholds;
        emit UpdatedThresholds(thresholds);
    }

    function updateReserve(address _reserve) public onlyOwner {
        reserve = _reserve;
        emit UpdatedReserve(reserve);
    }

    function addExempt(address _exempted) public onlyOwner {
        require(!exempts[_exempted], 'Exempt address already existent'); 
            
        exempts[_exempted] = true;
        emit AddedExempt(_exempted);
    }

     function updateExempt(address _exempted, bool isValid) public onlyOwner {
        require(exempts[_exempted], 'Exempt address is not existent'); 

        exempts[_exempted] = isValid;
        emit UpdatedExempt(_exempted, isValid);
    }

    function removeExempt(address _exempted) public onlyOwner {
        require(exempts[_exempted], 'Exempt address is not existent'); 

        exempts[_exempted] = false;
        emit RemovedExempt(_exempted);
    }

    // internal functions
    function _initializeExempts() internal {
        // initialize the following exempts: 
        // These accounts are exempted from taxation
        exempts[reserve] = true;
        exempts[0xf164fC0Ec4E93095b804a4795bBe1e041497b92a] = true; // UniswapV1Router01
        exempts[0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D] = true; // UniswapV2Router02
        exempts[0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F] = true; // Sushiswap: Router
        exempts[0xdb38ae75c5F44276803345f7F02e95A0aeEF5944] = true; // 1inch
        exempts[0xBA12222222228d8Ba445958a75a0704d566BF2C8] = true; // Balancer Vault

        emit InitializedExempts(1);
    } 

    function _getTaxPercentage(
        address _from,
        uint _sentAmount
    ) internal returns (uint tax) {
        uint taxPercentage = 0;
        uint balanceOfSenderOrFrom = balanceOf(_from);

        require(
            balanceOfSenderOrFrom > 0 && _sentAmount > 0,
            'Intangible balance or amount to send'
        );

        address accountLiable = transferMode == TRANSFER_FROM
            ? _from
            : msg.sender; 

        if (exempts[accountLiable]) return taxPercentage;

        uint percentageTransferred = _sentAmount.mul(100).div(balanceOfSenderOrFrom);

        if (percentageTransferred <= thresholds[0]) {
            taxPercentage = startingTaxes[0];
        }else if (percentageTransferred <= thresholds[1]) {
            taxPercentage = startingTaxes[1];
        }else if (percentageTransferred <= thresholds[2]) {
            taxPercentage = startingTaxes[2];
        }else if (percentageTransferred <= thresholds[3]) {
            taxPercentage = startingTaxes[3];
        } else if (percentageTransferred <= thresholds[4]) {
            taxPercentage = startingTaxes[4];
        } else {
            taxPercentage = startingTaxes[5];
        }
        
        _setGenesisTaxRecord(accountLiable, taxPercentage);
        emit GotTax(_from, _sentAmount, balanceOfSenderOrFrom, percentageTransferred, taxPercentage);
        return taxPercentage;
    }

    function _getReceivedAmount(
        address _from,
        uint _sentAmount
    ) internal returns (uint receivedAmount, uint taxAmount) {
        uint taxPercentage = _getTaxPercentage(_from, _sentAmount);
        receivedAmount = _sentAmount.sub(_sentAmount.div(BPS).mul(taxPercentage));
        taxAmount = _sentAmount.sub(receivedAmount);
    }

    function _setGenesisTaxRecord(
        address _addr, 
        uint _tax
        ) internal {
        uint timestamp = block.timestamp;
        genesis[_addr].push(TaxRecord({ 
            timestamp: timestamp,
            tax: _tax,
            balance: balanceOf(_addr)
        }));
        emit TaxRecordSet(_addr, timestamp, balanceOf(_addr), _tax);
    }

    function _internalTransfer(
        address _from, // `msg.sender` || `from`
        address _to,
        uint _amount
    ) internal returns (bool success){
        (, uint taxAmount) = _getReceivedAmount(_from, _amount);
        require(
            balanceOf(_from) > _amount.add(taxAmount),
            'Cannot afford to pay tax'
        ); 
        
        if(taxAmount > 0) {
            _burn(_from, taxAmount);
            _mint(reserve, taxAmount);
        }
        
        transferMode == TRANSFER 
            ? super.transfer(_to, _amount) 
            : super.transferFrom(_from, _to, _amount);

        return true;
    }

    // Sandbox functions
    function sandboxSetGenesisTaxRecord(
        address addr, 
        uint _tax
        ) public {
        uint timestamp = block.timestamp;
        sandboxGenesis[addr].push(TaxRecord({ 
            timestamp: timestamp,
            tax: _tax,
            balance: balanceOf(addr)
        }));
        emit SandboxTaxRecordSet(addr, timestamp, balanceOf(addr), _tax);
    }
}
