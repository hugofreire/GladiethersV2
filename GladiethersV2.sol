pragma solidity ^0.4.20;

contract Gladiethers
{
    address public m_Owner;
    address public partner;

    mapping (address => uint) public gladiatorToPower; // gladiator power
    mapping (address => uint) public gladiatorToCooldown;
    mapping (address => uint) public gladiatorToLuckyPoints;
    mapping(address => uint)  public gladiatorToQueuePosition;
    mapping(address => bool)  public trustedContracts;
    uint public m_OwnerFees = 0;
    uint public initGameAt = 0;
    address public kingGladiator;
    address public kingGladiatorFounder;
    address[] public queue;
    
    bool started = false;


    event fightEvent(address indexed g1,address indexed g2,uint random,uint fightPower,uint g1Power);
    modifier OnlyOwnerAndContracts() {
        require(msg.sender == m_Owner ||  trustedContracts[msg.sender]);
        _;
    }
    function ChangeAddressTrust(address contract_address,bool trust_flag) public OnlyOwnerAndContracts() {
        require(msg.sender != contract_address);
        trustedContracts[contract_address] = trust_flag;
    }
    
    function Gladiethers() public{
        m_Owner = msg.sender;
    }
    
    function setPartner(address contract_partner) public OnlyOwnerAndContracts(){
        partner = contract_partner;
    }

    function joinArena() public payable returns (bool){

        require( msg.value >= 10 finney && tx.origin == msg.sender );

        if(queue.length > gladiatorToQueuePosition[msg.sender]){

            if(queue[gladiatorToQueuePosition[msg.sender]] == msg.sender){
                gladiatorToPower[msg.sender] += msg.value;
                checkKingFounder(msg.sender);
                return false;
            }
        }
        
        enter(msg.sender);
        return true;  

    }

    function enter(address gladiator) private{
        gladiatorToCooldown[gladiator] = now + 1 days;
        queue.push(gladiator);
        gladiatorToQueuePosition[gladiator] = queue.length - 1;
        gladiatorToPower[gladiator] += msg.value;
        checkKingFounder(gladiator);
        
    }
    
    function checkKingFounder(address gladiator) internal{
        if(gladiatorToPower[gladiator] > gladiatorToPower[kingGladiatorFounder] && now < initGameAt){
            kingGladiatorFounder = gladiator;
        }
    }

    function remove(address gladiator) private returns(bool){
        
        if(queue.length > gladiatorToQueuePosition[gladiator]){

            if(queue[gladiatorToQueuePosition[gladiator]] == gladiator){ // is on the line ?
            
                queue[gladiatorToQueuePosition[gladiator]] = queue[queue.length - 1];
                gladiatorToQueuePosition[queue[queue.length - 1]] = gladiatorToQueuePosition[gladiator];
                delete queue[queue.length - 1];
                queue.length = queue.length - (1);
                return true;
                
            }
           
        }
        return false;
        
        
    }


    function setCooldown(address gladiator, uint cooldown) internal{
        gladiatorToCooldown[gladiator] = cooldown;
    }
    
    function getGladiatorCooldown(address gladiator) public view returns (uint){
        return gladiatorToCooldown[gladiator];
    }
    

    function getGladiatorPower(address gladiator) public view returns (uint){
        return gladiatorToPower[gladiator];
    }
    
    function getQueueLenght() public view returns (uint){
        return queue.length;
    }
    
    function reduceTime() public{ // Reduce 1 hour and uses 250 luckypoints
        
        require(gladiatorToLuckyPoints[msg.sender] >= 250 && tx.origin == msg.sender && getGladiatorPower(msg.sender) >= 10 finney 
        && SafeMath.sub(gladiatorToCooldown[msg.sender]- 60 minutes,now) >= 60 minutes ); // 1 hour Cap
        
        gladiatorToLuckyPoints[msg.sender] = SafeMath.sub(gladiatorToLuckyPoints[msg.sender],250);
        gladiatorToCooldown[msg.sender] = SafeMath.sub(gladiatorToCooldown[msg.sender],60 minutes);
        
    }
    
    function kingAttack() public {
        
        // prevent contracts from playing
        // need more than 249 luckypoints
        // prevent the attack if the king is not there yet 
        require(gladiatorToLuckyPoints[msg.sender] >= 250 && tx.origin == msg.sender && kingGladiator != address(0) && msg.sender != kingGladiator); 
        
        gladiatorToLuckyPoints[msg.sender] = SafeMath.sub(gladiatorToLuckyPoints[msg.sender],250);
        remove(msg.sender); // removes the atacker
        fight(kingGladiator);
        
    }
    
    function attack() public{
        
        require( tx.origin == msg.sender);
        
        remove(msg.sender);
        uint indexgladiator2 = random(queue.length,uint8(msg.sender)); 
        address gladiator2 = queue[indexgladiator2];
        
        fight(gladiator2);
        
    }
    function fight(address gladiator2) internal {
        
        address gladiator1 = msg.sender;
        
        require(now > initGameAt && getQueueLenght() > 0 && getGladiatorPower(msg.sender) >= 10 finney);
        
      
            uint randomNumber = random(1000,uint8(msg.sender));
           
            uint g1chance = gladiatorToPower[gladiator1];
            uint g2chance =  gladiatorToPower[gladiator2];
            uint fightPower = SafeMath.add(g1chance,g2chance);
    
            g1chance = (g1chance*1000)/fightPower;
    
            if(g1chance <= 958){
                g1chance = SafeMath.add(g1chance,40);
            }else{
                g1chance = 998;
            }
    
            fightEvent( gladiator1, gladiator2,randomNumber,fightPower,gladiatorToPower[gladiator1]);
            uint devFee;
    
            if(randomNumber <= g1chance ){ // Wins the Attacker
                devFee = SafeMath.div(SafeMath.mul(gladiatorToPower[gladiator2],5),100);
    
                gladiatorToPower[gladiator1] =  SafeMath.add( gladiatorToPower[gladiator1], SafeMath.sub(gladiatorToPower[gladiator2],devFee) );
                queue[gladiatorToQueuePosition[gladiator2]] = gladiator1;
                gladiatorToQueuePosition[gladiator1] = gladiatorToQueuePosition[gladiator2];
                gladiatorToPower[gladiator2] = 0;
                gladiatorToCooldown[gladiator1] = now + 1 days; // reset atacker cooldown
                
                gladiatorToLuckyPoints[gladiator2] = SafeMath.add(gladiatorToLuckyPoints[gladiator2],SafeMath.div(g1chance,10)); // gladiether2 gains luckypoints correlated to the chance of the winner glad1
                
                if(gladiatorToPower[gladiator1] > gladiatorToPower[kingGladiator] ){ // check if is the biggest guy in the arena
                    kingGladiator = gladiator1;
                }
    
            }else{
                //Defender Wins
                devFee = SafeMath.div(SafeMath.mul(gladiatorToPower[gladiator1],5),100);
                
                gladiatorToPower[gladiator2] = SafeMath.add( gladiatorToPower[gladiator2],SafeMath.sub(gladiatorToPower[gladiator1],devFee) );
                gladiatorToPower[gladiator1] = 0;
                
                gladiatorToLuckyPoints[gladiator1] = SafeMath.add(gladiatorToLuckyPoints[gladiator1],SafeMath.div(SafeMath.sub(1000,g1chance),10));// gladiether1 gains luckypoints for losing 
    
                if(gladiatorToPower[gladiator2] > gladiatorToPower[kingGladiator] ){
                    kingGladiator = gladiator2;
                }

        }

        
            kingGladiator.transfer(SafeMath.div(devFee,5)); // gives 1%      (5% dead gladiator / 5 )
            kingGladiatorFounder.transfer(SafeMath.div(devFee,5)); // gives 1%      (5% dead gladiator / 5 )
            m_OwnerFees = SafeMath.add( m_OwnerFees , SafeMath.sub(devFee, SafeMath.mul(SafeMath.div(devFee,5) ,2) ) ); // 5 total - 1king - 1kingfounder  = 3%
            

    }


    function withdraw(uint amount) public  returns (bool success){
        address withdrawalAccount;
        uint withdrawalAmount;

        // owner and partner can withdraw
        if (msg.sender == m_Owner || msg.sender == partner ) {
            withdrawalAccount = m_Owner;
            withdrawalAmount = m_OwnerFees;
            uint partnerFee = SafeMath.div(SafeMath.mul(withdrawalAmount,15),100);

            // set funds to 0
            m_OwnerFees = 0;

            if (!m_Owner.send(SafeMath.sub(withdrawalAmount,partnerFee))) revert(); // send to owner
            if (!partner.send(partnerFee)) revert(); // send to partner

            return true;
        }else{

            withdrawalAccount = msg.sender;
            withdrawalAmount = amount;

            // cooldown has been reached and the ammout i possible
            if(gladiatorToCooldown[msg.sender] < now && gladiatorToPower[withdrawalAccount] >= withdrawalAmount){

                gladiatorToPower[withdrawalAccount] = SafeMath.sub(gladiatorToPower[withdrawalAccount],withdrawalAmount);

                // gladiator have to be removed from areana if the power is less then 0.01 eth
                if(gladiatorToPower[withdrawalAccount] < 10 finney){
                    remove(msg.sender);
                }
                if(msg.sender == kingGladiator){
                    selectNewKing();
                }

            }else{
                return false;
            }

        }

        if (withdrawalAmount == 0) revert();

        // send the funds
        if (!msg.sender.send(withdrawalAmount)) revert();


        return true;
    }
    
    function selectNewKing(){
        
        address newKing = address(0);
        uint256 newKingPower=0;

        for(uint i;i<queue.length;i++) {
            if(getGladiatorPower(queue[i]) > newKingPower){
                newKing = queue[i];
                newKingPower = getGladiatorPower(queue[i]);
            }
        }
        
        kingGladiator = newKing;
    }
    
     // The upper bound of the number returns is 2^bits - 1
    function bitSlice(uint256 n, uint256 bits, uint256 slot) public pure returns(uint256) {
        uint256 offset = slot * bits;
        // mask is made by shifting left an offset number of times
        uint256 mask = uint256((2**bits) - 1) << offset;
        // AND n with mask, and trim to max of 5 bits
        return uint256((n & mask) >> offset);
    }

    function maxRandom(uint8 seed) public returns (uint256 randomNumber) {
       uint256 _seed = _seed + seed;
        _seed = uint256(keccak256(
            _seed,
            block.blockhash(block.number - 1),
            block.coinbase,
            block.difficulty
        ));
        return _seed;
    }

    // return a pseudo random number between lower and upper bounds
    // given the number of previous blocks it should hash.

    function random(uint256 upper,uint8 seed) internal returns (uint256 randomNumber) {
        randomNumber = maxRandom(seed) % upper;
        return randomNumber;

    }


}

library SafeMath {

    /**
    * @dev Multiplies two numbers, throws on overflow.
    */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }

    /**
    * @dev Integer division of two numbers, truncating the quotient.
    */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    /**
    * @dev Substracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    /**
    * @dev Adds two numbers, throws on overflow.
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}
