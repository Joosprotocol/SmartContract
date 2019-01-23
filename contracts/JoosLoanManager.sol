pragma solidity ^0.4.24;

import "../node_modules/openzeppelin-solidity/contracts/ownership/Ownable.sol";

contract JoosLoanManager is Ownable {

    uint8 constant FILLING_STAGE_NOT_DECLARED = 0;
    uint8 constant FILLING_STAGE_DECLARED = 1;
    uint8 constant FILLING_STAGE_FULL = 2;

    uint8 constant STATUS_DEFAULT = 0;
    uint8 constant STATUS_SIGNED = 1;
    uint8 constant STATUS_PAID = 2;
    uint8 constant STATUS_PAUSED = 3;
    uint8 constant STATUS_OVERDUE = 4;

    struct Loan {
        uint id;
        User lender;
        User borrower;
        uint amount;
        uint8 currency_type;
        uint period;
        uint8 percent;
        uint8 init_type;
        string personal;
        uint8 filling_stage ;
        uint8 status;
        uint created_at;
    }

    struct User {
        uint id;
        string name;
    }

    mapping(uint => Loan) private loans;

    constructor(address _newOwner) public {
        transferOwnership(_newOwner);
    }


    function getLoanInfo(uint _id)
    public
    view
    returns (
        uint amount,
        uint8 currency_type,
        uint period,
        uint percent,
        uint8 init_type,
        uint created_at
    ) {
        return (
        loans[_id].amount,
        loans[_id].currency_type,
        loans[_id].period,
        loans[_id].percent,
        loans[_id].init_type,
        loans[_id].created_at
        );
    }

    function getLoanParticipants(uint _id)
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
        loans[_id].lender.id,
        loans[_id].lender.name,
        loans[_id].borrower.id,
        loans[_id].borrower.name,
        loans[_id].personal
        );

    }

    function getStatus(uint _id) public view returns(uint8) {
        if (loans[_id].status == STATUS_SIGNED && isOverdue(_id)) {
            return STATUS_OVERDUE;
        }
        return loans[_id].status;
    }

    function initLoan(
        uint _id,
        uint _amount,
        uint8 _currency_type,
        uint _period,
        uint8 _percent,
        uint8 _init_type
    ) public onlyOwner returns (bool) {

        require(loans[_id].filling_stage == FILLING_STAGE_NOT_DECLARED);

        loans[_id].id = _id;
        loans[_id].amount = _amount;
        loans[_id].currency_type = _currency_type;
        loans[_id].period = _period;
        loans[_id].percent = _percent;
        loans[_id].init_type = _init_type;
        loans[_id].filling_stage = FILLING_STAGE_DECLARED;
        loans[_id].created_at = block.timestamp;
        return true;
    }

    function setLoanParticipants(
        uint _loan_id,
        uint _lender_id,
        string memory _lender_name,
        uint _borrower_id,
        string memory _borrower_name,
        string memory _personal
    ) public onlyOwner returns  (bool) {
        require(isDeclared(_loan_id));

        User memory lender = User({
            id : _lender_id,
            name : _lender_name
            });
        User memory borrower = User({
            id : _borrower_id,
            name : _borrower_name
            });

        loans[_loan_id].lender = lender;
        loans[_loan_id].borrower = borrower;
        loans[_loan_id].personal = _personal;
        loans[_loan_id].filling_stage = FILLING_STAGE_FULL;
        loans[_loan_id].status = STATUS_SIGNED;

        return true;

    }

    function setStatus(uint _id, uint8 _status) public onlyOwner returns(bool) {
        require(_status == STATUS_SIGNED || _status == STATUS_PAID || _status == STATUS_PAUSED);
        require(loans[_id].status != STATUS_PAID);
        loans[_id].status = _status;
        return true;
    }

    function isDeclared(uint _id) public view returns(bool) {
        return loans[_id].filling_stage == FILLING_STAGE_DECLARED;
    }

    function isFull(uint _id) public view returns(bool) {
        return loans[_id].filling_stage == FILLING_STAGE_FULL;
    }

    function isOverdue(uint _id) public view returns(bool) {
        return (block.timestamp > loans[_id].created_at + loans[_id].period);
    }

}