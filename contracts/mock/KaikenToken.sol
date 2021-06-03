// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract KaikenToken is ERC20 {
    using SafeMath for uint;

    // Addresses 
    address owner; // dev
    address private investors = 0x456ee95063e52359530b9702C9A3d1EEB46864A7;
    address private exchanges = 0xa611d21b868f2A1d9Cfb383152DC3483Ea15F81F;
    address private marketing = 0x085BA6bef0b3fEACf2D4Cb3Dba5CA11520E2AD01;
    address private reserve = 0xFe76451745386702e091113170b703096dC9E024;
    
    //structs 
    struct TaxRecord {
        uint timestamp;
        uint tax;
        uint balance;
    }
    
    struct GenesisRecord {
        uint timestamp;
        uint balance;
    }

    uint transferMode;
    uint[] startingTaxes = [
        5,
        8,
        10,
        15,
        20,
        25,
        30
    ];

     uint[] thresholds = [
        5,
        10,
        20,
        30,
        40,
        50
    ];

    // constants 
    uint private constant BPS = 100;
    uint private constant ONE_YEAR = 365;
    uint private constant TRANSFER = 0;
    uint private constant TRANSFER_FROM = 1;
    
    // constants for tokenomics (%)
    uint private OWNER = 20000000000;
    uint private RESERVE = 30000000000;
    uint private INVESTORS = 15000000000;
    uint private EXCHANGES = 20000000000;
    uint private MARKETING = 15000000000;

    // mappings
    mapping(address => bool) exempts;
    mapping(address => bool) totalExempts;
    mapping(address => TaxRecord[]) accountTaxMap;
    mapping(address => TaxRecord[]) sandboxAccountTaxMap;
    mapping(address => GenesisRecord) genesis;
    

    //modifiers
    modifier onlyOwner {
        require(msg.sender == owner, 'Only the owner can invoke this call.');
        _;
    }
    // events
    event AddedExempt(address exempted);
    event RemovedExempt(address exempted);
    event RemovedTotalExempt(address exempted);
    event UpdatedExempt(address exempted, bool isValid);
    event UpdatedTotalExempt(address exempted, bool isValid);
    event UpdatedReserve(address reserve);
    event TaxRecordSet(address _addr, uint timestamp, uint balance, uint tax);
    event UpdatedStartingTaxes(uint[] startingTaxes);
    event UpdatedThresholds(uint[] thresholds);
    event InitializedExempts(uint initialized);
    event InitializedTotalExempts(uint initialized);

    // sandbox events
    event SandboxTaxRecordSet(address addr, uint timestamp, uint balance, uint tax);

    constructor(
        string memory _name,
        string memory _symbol
    ) public ERC20(_name, _symbol) {
        owner = msg.sender;
        _mint(owner, OWNER * (10 ** uint256(decimals())));
        _mint(reserve, RESERVE * (10 ** uint256(decimals())));
        _mint(exchanges, EXCHANGES * (10 ** uint256(decimals())));
        _mint(investors, INVESTORS * (10 ** uint256(decimals())));
        _mint(marketing, MARKETING * (10 ** uint256(decimals())));
        
        _initializeExempts();
        _initializeTotalExempts();
    }

    // Overrides
    function transfer(
        address to,
        uint amount
    ) public virtual override returns (bool){
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

    function getTotalExempt(address _addr) public view returns(bool){
        return totalExempts[_addr];
    }
    
    function getTaxRecord(address _addr) public view returns(TaxRecord[] memory){
        return accountTaxMap[_addr];
    }
    
    function getGenesisRecord(address _addr) public view returns(GenesisRecord memory){
        return genesis[_addr];
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

    function addExempt(address _exempted, bool totalExempt) public onlyOwner {
        require(_exempted != owner, 'Cannot tax exempt the owner');
        _addExempt(_exempted, totalExempt);
    }

    function updateExempt(address _exempted, bool isValid) public onlyOwner {
        require(_exempted != owner, 'Can not update Owners tax exempt status');
        exempts[_exempted] = isValid;
        emit UpdatedExempt(_exempted, isValid);
    }

    function updateTotalExempt(address _exempted, bool isValid) public onlyOwner {
        require(_exempted != owner, 'Can not update Owners tax exempt status');
        totalExempts[_exempted] = isValid;
        if(isValid) {
            exempts[_exempted] = false;
        }
        emit UpdatedTotalExempt(_exempted, isValid);
    }

    function removeExempt(address _exempted) public onlyOwner {
        require(exempts[_exempted], 'Exempt address is not existent'); 

        exempts[_exempted] = false;
        emit RemovedExempt(_exempted);
    }

    function removeTotalExempt(address _exempted) public onlyOwner {
        require(totalExempts[_exempted], 'Total Exempt address is not existent'); 

        totalExempts[_exempted] = false;
        emit RemovedTotalExempt(_exempted);
    }

    // internal functions
    function _addExempt(address _exempted, bool totalExempt) internal {
        require(!exempts[_exempted] || !totalExempts[_exempted], 'Exempt address already existent'); 

        if(totalExempt == false) {
            exempts[_exempted] = true;
        } else {
            totalExempts[_exempted] = true;
            exempts[_exempted] = false;
        }
        emit AddedExempt(_exempted);    
    }
    
    function _initializeExempts() internal {
        // initialize the following exempts: 
        // These accounts are exempted from taxation
        exempts[exchanges] = true;
        exempts[investors] = true;
        exempts[marketing] = true;
        exempts[0xf164fC0Ec4E93095b804a4795bBe1e041497b92a] = true; // UniswapV1Router01
        exempts[0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D] = true; // UniswapV2Router02
        exempts[0xE592427A0AEce92De3Edee1F18E0157C05861564] = true; // UniswapV3Router03
        exempts[0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F] = true; // Sushiswap: Router
        exempts[0xdb38ae75c5F44276803345f7F02e95A0aeEF5944] = true; // 1inch
        exempts[0xBA12222222228d8Ba445958a75a0704d566BF2C8] = true; // Balancer Vault

        emit InitializedExempts(1);
    } 

    function _initializeTotalExempts() internal {
        // initialize the following total exempts: 
        // These accounts are exempt the to and from accounts that 
        // interact with them. This is for certain exchanges that fail 
        // with any forms of taxation. 
        totalExempts[reserve] = true;
        totalExempts[0xCCE8D59AFFdd93be338FC77FA0A298C2CB65Da59] = true; // Bilaxy1
        totalExempts[0xB5Ef14898928FDCE71b54Ea80350B76F9a3617a6] = true; // Bilaxy2
        totalExempts[0x9BA3560231e3E0aD7dde23106F5B98C72E30b468] = true; // Bilaxy3
        
        emit InitializedTotalExempts(1);
    } 

    function _getTaxPercentage(
        address _from,
        address _to,
        uint _sentAmount
    ) internal returns (uint tax) {
        uint taxPercentage = 0;
        uint fromBalance = balanceOf(_from);
        uint noww = block.timestamp;

        require(
            fromBalance > 0 && _sentAmount > 0,
            'Intangible balance or amount to send'
        );

        bool isDueForTaxExemption =
            !exempts[_from] &&
            !totalExempts[_from] &&
            genesis[_from].timestamp > 0 &&
            genesis[_from].balance > 0 &&
            balanceOf(_from) >= genesis[_from].balance && 
            noww - genesis[_from].timestamp >= ONE_YEAR * 1 days;

        if (isDueForTaxExemption) _addExempt(_from, false);
        
        // Do not tax any transfers associated with total exemptions
        // Do not tax any transfers from exempted accounts
        if (
            exempts[_from] ||
            totalExempts[_from] ||
            totalExempts[_to]
        ) return taxPercentage;

        uint percentageTransferred = _sentAmount.mul(100).div(fromBalance);

        if (percentageTransferred <= thresholds[0]) {
            taxPercentage = startingTaxes[0];
        } else if (percentageTransferred <= thresholds[1]) {
            taxPercentage = startingTaxes[1];
        } else if (percentageTransferred <= thresholds[2]) {
            taxPercentage = startingTaxes[2];
        } else if (percentageTransferred <= thresholds[3]) {
            taxPercentage = startingTaxes[3];
        } else if (percentageTransferred <= thresholds[4]) {
            taxPercentage = startingTaxes[4];
        } else if (percentageTransferred <= thresholds[5]) {
            taxPercentage = startingTaxes[5];
        } else {
            taxPercentage = startingTaxes[6];
        }
        
        _setTaxRecord(_from, taxPercentage);
        return taxPercentage;
    }

    function _getReceivedAmount(
        address _from,
        address _to,
        uint _sentAmount
    ) internal returns (uint receivedAmount, uint taxAmount) {
        uint taxPercentage = _getTaxPercentage(_from, _to, _sentAmount);
        receivedAmount = _sentAmount.sub(_sentAmount.div(BPS).mul(taxPercentage));
        taxAmount = _sentAmount.sub(receivedAmount);
    }

    function _setTaxRecord(
        address _addr, 
        uint _tax
        ) internal {
        uint timestamp = block.timestamp;
        accountTaxMap[_addr].push(TaxRecord({ 
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
        uint noww = block.timestamp;
        
        if(_from == owner && !exempts[owner]) {
            // timelock owner-originated transfers for a year. 
            require(noww >= 1654048565, 'Owner is timelocked for 1 year');
            _addExempt(owner, false);
        }
        
        if (transferMode == TRANSFER) {
            super.transfer(_to, _amount);
        } else {
            (, uint taxAmount) = _getReceivedAmount(_from, _to, _amount);
        
            require(
                balanceOf(_from) >= _amount.add(taxAmount),
                'Exclusive taxation: Cannot afford to pay tax'
            ); 
            
            if(taxAmount > 0) {
                _burn(_from, taxAmount);
                _mint(reserve, taxAmount);
            }
            
            super.transferFrom(_from, _to, _amount);
        }
        
        if (genesis[_to].timestamp == 0) {
            genesis[_to].timestamp = noww;
        }
    
        genesis[_to].balance = balanceOf(_to);
        genesis[_from].balance = balanceOf(_from);
        genesis[_from].timestamp = noww;
        
        return true;
    }

    // Sandbox functions
    function sandboxSetTaxRecord(
        address addr, 
        uint _tax
        ) public {
        uint noww = block.timestamp;
        sandboxAccountTaxMap[addr].push(TaxRecord({ 
            timestamp: noww,
            tax: _tax,
            balance: balanceOf(addr)
        }));
        emit SandboxTaxRecordSet(addr, noww, balanceOf(addr), _tax);
    }
    
     function sandboxGetTaxRecord(
        address addr
        ) public view returns (TaxRecord[] memory tr){
        tr = sandboxAccountTaxMap[addr];
    }
}
