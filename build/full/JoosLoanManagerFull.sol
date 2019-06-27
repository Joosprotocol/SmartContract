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

// File: node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol

/**
 * @title SafeMath
 * @dev Math operations with safety checks that revert on error
 */
library SafeMath {

    /**
    * @dev Multiplies two numbers, reverts on overflow.
    */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    /**
    * @dev Integer division of two numbers truncating the quotient, reverts on division by zero.
    */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0); // Solidity only automatically asserts when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
    * @dev Subtracts two numbers, reverts on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }

    /**
    * @dev Adds two numbers, reverts on overflow.
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }

    /**
    * @dev Divides two numbers and returns the remainder (unsigned integer modulo),
    * reverts when dividing by zero.
    */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

// File: contracts/JoosLoanManager.sol

contract JoosLoanManager is Ownable {
    using SafeMath for uint256;

    uint8 constant FILLING_STAGE_NOT_DECLARED = 0;
    uint8 constant FILLING_STAGE_DECLARED = 1;
    uint8 constant FILLING_STAGE_FULL = 2;

    uint8 constant STATUS_DEFAULT = 0;
    uint8 constant STATUS_SIGNED = 1;
    uint8 constant STATUS_PARTIALLY_PAID = 2;
    uint8 constant STATUS_PAID = 3;
    uint8 constant STATUS_PAUSED = 4;
    uint8 constant STATUS_OVERDUE = 5;

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

    struct Loan {
        bytes16 hash_id;
        User lender;
        User borrower;
        uint amount;
        uint8 currency_type;
        uint period;
        uint16 fee;
        uint8 init_type;
        string personal;
        uint8 filling_stage ;
        uint8 status;
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

    constructor(address _newOwner) public {
        transferOwnership(_newOwner);
    }

    function getLoanInfo(bytes16 _hash_id)
    public
    view
    returns (
        uint amount,
        uint8 currency_type,
        uint period,
        uint16 fee,
        uint8 init_type,
        uint created_at
    ) {
        return (
        loans[_hash_id].amount,
        loans[_hash_id].currency_type,
        loans[_hash_id].period,
        loans[_hash_id].fee,
        loans[_hash_id].init_type,
        loans[_hash_id].created_at
        );
    }

    function getLoanParticipants(bytes16 _hash_id)
    public
    view
    returns (
        uint lender_id,
        string memory lender_name,
        uint borrower_id,
        string memory borrower_name,
        string memory personal
    ) {
        return (
        loans[_hash_id].lender.id,
        loans[_hash_id].lender.name,
        loans[_hash_id].borrower.id,
        loans[_hash_id].borrower.name,
        loans[_hash_id].personal
        );

    }

    function getStatus(bytes16 _hash_id) public view returns(uint8) {
        require(isFull(_hash_id), 'Loan does not exist');
        if (_isOverdue(_hash_id) && !_isPaid(_hash_id)) {
            return STATUS_OVERDUE;
        }

        if (_isPaid(_hash_id)) {
            return STATUS_PAID;
        }

        if (getPaymentsCount(_hash_id) > 0) {
            return STATUS_PARTIALLY_PAID;
        }

        return STATUS_SIGNED;
    }

    function initLoan(
        bytes16 _hash_id,
        uint _amount,
        uint8 _currency_type,
        uint _period,
        uint16 _fee,
        uint8 _init_type
    ) public onlyOwner returns (bool) {

        require(loans[_hash_id].filling_stage == FILLING_STAGE_NOT_DECLARED);

        loans[_hash_id].hash_id = _hash_id;
        loans[_hash_id].amount = _amount;
        loans[_hash_id].currency_type = _currency_type;
        loans[_hash_id].period = _period;
        loans[_hash_id].fee = _fee;
        loans[_hash_id].init_type = _init_type;
        loans[_hash_id].filling_stage = FILLING_STAGE_DECLARED;
        loans[_hash_id].created_at = block.timestamp;
        return true;
    }

    function setLoanParticipants(
        bytes16 _hash_id,
        uint _lender_id,
        string memory _lender_name,
        uint _borrower_id,
        string memory _borrower_name,
        string memory _personal
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
        loans[_hash_id].personal = _personal;
        loans[_hash_id].filling_stage = FILLING_STAGE_FULL;
        loans[_hash_id].status = STATUS_SIGNED;

        return true;

    }

    function createPayment(
        bytes16 _hash_id,
        uint _amount
    ) public onlyOwner returns (bool) {
        require(isFull(_hash_id), 'Loan does not exist');
        require(!_isOverdue(_hash_id), 'Unable to make payments');
        loans[_hash_id].payments.push(Payment(_amount, block.timestamp));
        emit NewPayment(_hash_id, _amount);
        return true;
    }

    function getPaymentsCount(bytes16 _hash_id) public view returns (uint) {
        return loans[_hash_id].payments.length;
    }

    function getPaymentsTotalAmount(bytes16 _hash_id) public view returns (uint totalValue) {
        totalValue = 0;
        for (uint i=0; i < getPaymentsCount(_hash_id); i++) {
            totalValue = totalValue.add(loans[_hash_id].payments[i].amount);
        }
    }

    function _isPaid(bytes16 _hash_id) private view returns(bool) {
        uint paymentsTotalAmount = getPaymentsTotalAmount(_hash_id);
        if (paymentsTotalAmount >= calculateLoanAmountToPay(_hash_id)) {
            return true;
        }
        return false;
    }

    function isDeclared(bytes16 _hash_id) public view returns(bool) {
        return loans[_hash_id].filling_stage == FILLING_STAGE_DECLARED;
    }

    function isFull(bytes16 _hash_id) public view returns(bool) {
        return loans[_hash_id].filling_stage == FILLING_STAGE_FULL;
    }

    function _isOverdue(bytes16 _hash_id) private view returns(bool) {
        return (block.timestamp > loans[_hash_id].created_at.add(loans[_hash_id].period));
    }

    function calculateLoanAmountToPay(bytes16 _hash_id) public view returns(uint) {
        return (loans[_hash_id].amount.mul((100 * PERCENT_PRECISION).add(loans[_hash_id].fee)).div(100 * PERCENT_PRECISION));
    }

}
