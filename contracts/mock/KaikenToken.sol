// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract KaikenToken is ERC20 {
    using SafeMath for uint;

    address owner;
    address private reserve = 0x3FEE83b4a47D4D6425319A09b91C0559DDF9E31C; // My Sola ETH Account

    uint transferMode;
    uint[] startingTaxes = [
        25,
        30,
        35,
        40,
        45
    ];

     uint[] thresholds = [
        10,
        20,
        30,
        40,
        50
    ];

    uint taxReductionStep = 1;
    uint maxTaxReductions = 24;
    uint taxReductionCadence = 31; 

    //structs 
    struct TaxRecord {
        uint timestamp;
        uint taxReductions;
    }

    // constants 
    uint private constant BPS = 100;
    uint private constant TOTAL_SUPPLY = 100000000000;
    uint private constant TRANSFER = 0;
    uint private constant TRANSFER_FROM = 1;

    // mappings
    mapping(address => bool) exempts;
    mapping(address => TaxRecord) genesis;
    mapping(address => TaxRecord) sandboxGenesis;

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
    event UpdatedTaxReductionCadence(uint cadence);
    event TaxReduced(
        address accountLiable, 
        uint now
    );
    event TaxRecordSet(address _addr, uint timestamp, uint taxReductions);
    event UpdatedStartingTaxes(uint[] startingTaxes);
    event UpdatedTaxReductionStep(uint taxReductionStep);
    event UpdatedMaxTaxReductions(uint maxTaxReductions);
    event UpdatedThresholds(uint[] thresholds);
    event GotTax(address msgSender, uint sentAmount, uint balanceOfSenderOrFrom, uint percentageTransferred , uint taxPercentage);

    // sandbox events
    event SandboxTaxRecordSet(address _addr, uint timestamp, uint taxReductions);

    constructor(
        string memory _name,
        string memory _symbol
    ) public ERC20(_name, _symbol) {
        owner = msg.sender;
        _mint(owner, TOTAL_SUPPLY * (10 ** uint256(decimals())));
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

    function getTaxReductionCadence() public view returns(uint) {
        return taxReductionCadence;
    }

    function getMaxTaxReductions() public view returns(uint) {
        return maxTaxReductions;
    }

    function getTaxReductionsFromGenesis(address _addr) public view returns(uint) {
        return genesis[_addr].taxReductions;
    }

    function isDueForTaxReduction(address accountLiable) public view returns(bool) {
        return (
            genesis[accountLiable].taxReductions <= maxTaxReductions &&
            (block.timestamp <= genesis[accountLiable].timestamp.add(taxReductionCadence * 1 days))
        );
    }

    // Writes
    function updateStartingTaxes(uint[] memory _startingTaxes) public onlyOwner {
        startingTaxes = _startingTaxes;
        emit UpdatedStartingTaxes(startingTaxes);
    }

    function updateTaxReductionStep(uint _step) public onlyOwner {
        taxReductionStep = _step;
        emit UpdatedTaxReductionStep(taxReductionStep);
    }

    function updateMaxTaxReductions(uint _maxTaxReductions) public onlyOwner {
        maxTaxReductions = _maxTaxReductions;
        emit UpdatedMaxTaxReductions(maxTaxReductions);
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

    function updateTaxReductionCadence(uint _taxReductionCadence) public onlyOwner {
        taxReductionCadence = _taxReductionCadence;
        emit UpdatedTaxReductionCadence(taxReductionCadence);
    }

    // internal functions
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
        } else {
            taxPercentage = startingTaxes[4];
        }

        if (genesis[accountLiable].timestamp == 0) {
            _setGenesisTaxRecord(accountLiable, 0);
        }

        bool isDue = isDueForTaxReduction(accountLiable);

        if (isDue) {
            genesis[accountLiable] = TaxRecord({ 
                timestamp: block.timestamp,
                taxReductions: genesis[accountLiable].taxReductions++
            });
            _setGenesisTaxRecord(accountLiable, genesis[accountLiable].taxReductions++);
            emit TaxReduced(
                accountLiable,
                block.timestamp
            );
        }
        
        taxPercentage = taxPercentage.sub(genesis[accountLiable].taxReductions.mul(taxReductionStep));
        
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
        uint _taxReductions
        ) internal {
        uint timestamp = block.timestamp;
        genesis[_addr] = TaxRecord({ 
            timestamp: timestamp,
            taxReductions: _taxReductions
        });
        emit TaxRecordSet(_addr, timestamp, _taxReductions);
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
    function sandboxIsDueForTaxReduction(address accountLiable) public view returns(bool) {
        return (
            sandboxGenesis[accountLiable].taxReductions <= maxTaxReductions &&
            (block.timestamp <= sandboxGenesis[accountLiable].timestamp.add(taxReductionCadence * 1 days))
        );
    }
    
    function sandboxSetGenesisTaxRecord(
        address _addr, 
        uint _taxReductions
        ) public {
        uint timestamp = block.timestamp;
        sandboxGenesis[_addr] = TaxRecord({ 
            timestamp: timestamp,
            taxReductions: _taxReductions
        });
        emit SandboxTaxRecordSet(_addr, timestamp, _taxReductions);
    }
}
