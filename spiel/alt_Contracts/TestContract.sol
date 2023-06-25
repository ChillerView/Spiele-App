contract Game {
    
    uint private entryFee;
    uint private serviceFee;

    function init(uint _entryFee, uint _serviceFee) public {
        entryFee = _entryFee;
        serviceFee = _serviceFee;
    }
}