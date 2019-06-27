pragma solidity ^0.5.1;

// File: node_modules/openzeppelin-solidity/contracts/ownership/Ownable.sol

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor() internal {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    /**
     * @return the address of the owner.
     */
    function owner() public view returns(address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner());
        _;
    }

    /**
     * @return true if `msg.sender` is the owner of the contract.
     */
    function isOwner() public view returns(bool) {
        return msg.sender == _owner;
    }

    /**
     * @dev Allows the current owner to relinquish control of the contract.
     * @notice Renouncing to ownership will leave the contract without an owner.
     * It will not be possible to call the functions with the `onlyOwner`
     * modifier anymore.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// File: contracts/JoosCollateralLoanManager.sol

contract JoosCollateralLoanManager is Ownable {

    constructor(address _newOwner) public {
        transferOwnership(_newOwner);
    }

    uint8 constant FILLING_STAGE_NOT_DECLARED = 0;
    uint8 constant FILLING_STAGE_DECLARED = 1;
    uint8 constant FILLING_STAGE_FULL = 2;

    uint8 constant STATUS_SIGNED = 1; // it's default status if contract deployed to network
    uint8 constant STATUS_PARTIALLY_PAID = 2;
    uint8 constant STATUS_PAID = 3;
    uint8 constant STATUS_PAUSED = 4;
    uint8 constant STATUS_OVERDUE = 5;
    uint8 constant STATUS_WITHDRAWN = 6;

    uint constant PERCENT_PRECISION = 100;

    event LoanSigned(
        bytes16 _hash_id,
        uint _amount,
        uint8 _currency_type
    );

    event NewPayment(
        bytes16 _hash_id,
        uint _amount
    );

    event Withdraw(
        bytes16 _hash_id
    );

    struct Collateral {
        bytes16[] loans;
    }

    struct Loan {
        bytes16 hash_id;
        bytes16 collateral_hash_id;
        User lender;
        User borrower;
        bool is_platform;
        bool is_withdrawn;
        uint amount;
        uint8 currency_type;
        uint collateral_amount;
        uint8 collateral_currency_type;
        uint period;
        uint16 fee;
        uint8 filling_stage;
        Payment[] payments;
        uint created_at;
    }



    struct User {
        uint id;
        string name;
    }

    struct Payment {
        uint amount;
        uint created_at;
    }

    mapping(bytes16 => Loan) private loans;

    mapping(bytes16 => Collateral) private collaterals;

    function getCollateralLoanHashId(bytes16 _hash_id, uint _number)
    public
    view
    returns (
        bytes16
    ) {
        return collaterals[_hash_id].loans[_number];
    }

    function getCollateralLoanCount(bytes16 _hash_id)
    public
    view
    returns (
        uint
    ) {
        return collaterals[_hash_id].loans.length;
    }

    function getLoanInfo(bytes16 _hash_id)
    public
    view
    returns (
        uint amount,
        uint8 currency_type,
        uint collateral_amount,
        uint8 collateral_currency_type,
        uint period,
        uint16 fee,
        uint created_at
    ) {
        return (
        loans[_hash_id].amount,
        loans[_hash_id].currency_type,
        loans[_hash_id].collateral_amount,
        loans[_hash_id].collateral_currency_type,
        loans[_hash_id].period,
        loans[_hash_id].fee,
        loans[_hash_id].created_at
        );
    }

    function getLoanCollateralHashId(bytes16 _hash_id)
    public
    view
    returns (
        bytes16 collateral_hash_id
    ) {
        return (loans[_hash_id].collateral_hash_id);
    }

    function getLoanParticipants(bytes16 _hash_id)
    public
    view
    returns (
        uint lender_id,
        string memory lender_name,
        uint borrower_id,
        string memory borrower_name,
        bool is_platform
    ) {
        return (
        loans[_hash_id].lender.id,
        loans[_hash_id].lender.name,
        loans[_hash_id].borrower.id,
        loans[_hash_id].borrower.name,
        loans[_hash_id].is_platform
        );
    }

    function getStatus(bytes16 _hash_id) public view returns(uint8) {
        if (loans[_hash_id].is_withdrawn == true) {
            return STATUS_WITHDRAWN;
        }

        if (isOverdue(_hash_id) && !isPaid(_hash_id)) {
            return STATUS_OVERDUE;
        }

        if (isPaid(_hash_id)) {
            return STATUS_PAID;
        }

        if (getPaymentsCount(_hash_id) > 0) {
            return STATUS_PARTIALLY_PAID;
        }

        return STATUS_SIGNED;
    }

    function initLoan(
        bytes16 _hash_id,
        bytes16 _collateral_hash_id,
        uint _amount,
        uint8 _currency_type,
        uint _collateral_amount,
        uint8 _collateral_currency_type,
        uint _period,
        uint16 _fee
    ) public onlyOwner returns (bool) {

        require(loans[_hash_id].filling_stage == FILLING_STAGE_NOT_DECLARED);

        loans[_hash_id].hash_id = _hash_id;
        loans[_hash_id].collateral_hash_id = _collateral_hash_id;
        loans[_hash_id].amount = _amount;
        loans[_hash_id].currency_type = _currency_type;
        loans[_hash_id].collateral_amount = _collateral_amount;
        loans[_hash_id].collateral_currency_type = _collateral_currency_type;
        loans[_hash_id].period = _period;
        loans[_hash_id].fee = _fee;
        loans[_hash_id].filling_stage = FILLING_STAGE_DECLARED;
        loans[_hash_id].created_at = block.timestamp;
        loans[_hash_id].is_withdrawn = false;

        collaterals[_collateral_hash_id].loans.push(_hash_id);
        return true;
    }

    function setLoanParticipants(
        bytes16 _hash_id,
        bool _is_platform,
        uint _borrower_id,
        string memory _borrower_name,
        uint _lender_id,
        string memory _lender_name
    ) public onlyOwner returns  (bool) {
        require(isDeclared(_hash_id));

        User memory lender = User({
            id : _lender_id,
            name : _lender_name
            });
        User memory borrower = User({
            id : _borrower_id,
            name : _borrower_name
            });

        loans[_hash_id].lender = lender;
        loans[_hash_id].borrower = borrower;
        loans[_hash_id].is_platform = _is_platform;
        loans[_hash_id].filling_stage = FILLING_STAGE_FULL;
        emit LoanSigned(_hash_id, loans[_hash_id].amount, loans[_hash_id].currency_type);
        return true;
    }

    function setAsWithdrawn(
        bytes16 _hash_id
    ) public onlyOwner returns (bool) {
        require(isPaid(_hash_id), 'The collateral can be returned after full payment of the loan.');
        loans[_hash_id].is_withdrawn = true;
        emit Withdraw(_hash_id);
        return true;
    }

    function createPayment(
        bytes16 _hash_id,
        uint _amount
    ) public onlyOwner returns (bool) {
        require(isFull(_hash_id), 'Collateral does not exist');
        require(!isOverdue(_hash_id), 'Unable to make payments');
        loans[_hash_id].payments.push(Payment(_amount, block.timestamp));
        emit NewPayment(_hash_id, _amount);
        return true;
    }

    function isDeclared(bytes16 _hash_id) public view returns(bool) {
        return loans[_hash_id].filling_stage == FILLING_STAGE_DECLARED;
    }

    function isFull(bytes16 _hash_id) public view returns(bool) {
        return loans[_hash_id].filling_stage == FILLING_STAGE_FULL;
    }

    function isOverdue(bytes16 _hash_id) public view returns(bool) {
        return (block.timestamp > loans[_hash_id].created_at + loans[_hash_id].period);
    }

    function getPaymentsCount(bytes16 _hash_id) public view returns (uint) {
        return loans[_hash_id].payments.length;
    }

    function getPaymentsTotalAmount(bytes16 _hash_id) public view returns (uint totalValue) {
        totalValue = 0;
        for (uint i=0; i < getPaymentsCount(_hash_id); i++) {
            totalValue += loans[_hash_id].payments[i].amount;
        }
    }

    function isPaid(bytes16 _hash_id) public view returns(bool) {
        uint paymentsTotalAmount = getPaymentsTotalAmount(_hash_id);
        if (paymentsTotalAmount >= calculateLoanAmountToPay(_hash_id)) {
            return true;
        }
        return false;
    }

    function calculateLoanAmountToPay(bytes16 _hash_id) public view returns(uint) {
        return (loans[_hash_id].amount * (100 * PERCENT_PRECISION + loans[_hash_id].fee) / (100 * PERCENT_PRECISION));
    }

}
