pragma solidity ^0.4.10;
/*prisoner contract 
//this is the contract should be signed by the client and the first and the second oracle node.
//If there is a collusion the client can inform the third part Trust oracle to participate and solve the collusion.
// for more info. go to the paper.
*/

contract prisoners {

    //addresses of parties
    address public Client;
    address public Oracle1;
    address public Oracle2;
    address public TrustOracle;

    mapping (address => uint ) public results;
    mapping (address => bool ) public hasBid;
    mapping (address => bool ) public hasDeliver;
    mapping (address => bool ) public Cheated;
   
    //Data description(client)
    string public Datadescription;
    
    //result(oracle)
    uint public result1;
    uint public result2;
    //result(Trust Oracle)
    uint public TrustResult;

    //deadlines
    uint public T1;
    uint public T2;
    uint public T3;

    //Client pay the wage to Oracle
    uint public wage ;
    //Oracle1 and Oracle2 pay the deposit to client
    uint public deposit ;
    //Trust Oracle cost
    uint public Thirdcost;


   //all the states
    enum State {INIT, Created, GetData, Pay, Done, Error, Aborted}
    
    //current state
    State public state = State.INIT;

    //constructor
    function prisoners() public{
        Client = msg.sender;
    }


    //fallback function
    function() payable {
      throw;
    }
    
    //Create function - Client call
    //The client needs to select Oracles to be workers and nominate Trust Oracle
    function Create (string _Datadescription, uint _wage, uint _deposit, uint _Thirdcost,  address[2] addr, address _TrustOracleaddr) payable returns(bool) {
          require(msg.sender == Client);
          
          //initiate contract parameters
          wage = _wage ;
          deposit = _deposit; 
          Thirdcost = _Thirdcost;
          Datadescription = _Datadescription;

          Oracle1 = addr[0];
          Oracle2 = addr[1];
          TrustOracle=_TrustOracleaddr;
        
    	  T1 = now + 10 minutes;
          T2 = now + 20 minutes;
          T3 = now + 30 minutes;
          
          //current time
          uint T = now;
          
          //sanity checks
          require(state == State.INIT );
          require(T<T1 && T1<T2 && T2<T3);
          //Client must pay this amount into the contract
          require(msg.value==((2 * wage) + Thirdcost));

          //change the state
          state = State.Created;
          
          //for debugging
          return true;
    }
    
    //Second Function Bid() - Oracle call
    function Bid() payable returns (bool sta) {
        //current time
        uint T = now; 
        //sanity checks
        require(state == State.Created);
        require(T < T1);
        require(msg.value == deposit);
        require(!hasBid[msg.sender]);
        require(msg.sender == Oracle1 || msg.sender == Oracle2);

        hasBid[msg.sender] = true;
        
        //change state if both have bid
        if (hasBid[Oracle1] == true && hasBid[Oracle2]== true ){ 
            state = State.GetData;
            
        }

        //for debugging
        return true;
    }// end Bid

    //third function DELIVER; takes one input; run by the Oracles only.
    function Deliver (uint result) returns (bool Do) {
        //current time
        uint T = now; 
        
        //sanity checks
        require(msg.sender == Oracle1 || msg.sender == Oracle2);
        require(state == State.GetData);
        require(T < T2);
        require(!hasDeliver[msg.sender]);
        
        //record the result
        if (msg.sender == Oracle1){
            result1 = result;
        }
        else {
            result2 = result;
        }
        hasDeliver[msg.sender] = true;

        // if both Oracles delivered results then change the state;
        if (hasDeliver[Oracle1] == true && hasDeliver[Oracle2] == true) {
                state = State.Pay;
        }
        
        //for debugging
        return true;
    } // end DELIVER
    
    // Fourth Function PAY; 
    function Pay () returns (bool Do){
        //current time
        uint T = now;

        //sanity checks
        require(state == State.Pay);
        require(T < T3);
        
        bool isdone;
        
        //if no one delivered
        if (hasDeliver[Oracle1] == false && hasDeliver[Oracle2]==false){
            //transfer the balance in the contract to the client
           isdone = Client.send(this.balance);
           require(isdone);
           //change the state
           state = State.Done;
        }
        //if both delivered
        else if (hasDeliver[Oracle1] == true && hasDeliver[Oracle2] == true){
            //if both results are equal
            if(result1 == result2){
                //pay the wage to Oracle1 and refund deposit 
                isdone = Oracle1.send(wage+deposit);
                require(isdone);
                
                //pay the wage to Oracle1 and refund deposit
                isdone = Oracle2.send(wage+deposit);
                require(isdone);
                
                //refund the client 
                isdone = Client.send(Thirdcost);
                require(isdone);
                //change the state
                state = State.Done;
                Do  = true;
            }
            //shouldn't reach here
            else {
                Do = false;
                state = State.Error;
            }

        }
        //shouldn't reach here
        else {
            Do = false;
            state = State.Error;
        }
        
        //for debugging
        return Do;
    }// end of PAY
    
    // Fifth Function DISPUTE, takes one input and returns bool
    // result from _TrustOracle: result0

    function Dispute(uint result0) returns (uint Done){
        // check the sender must be Trust Oracle else quit
        require(msg.sender == TrustOracle);
        
        //dispute resolution start

        TrustResult = result0;
        

        // check Oracle1's result
        if (hasDeliver[Oracle1] == true && TrustResult == result1){
            Cheated[Oracle1] = false;
        }
        else {
         Cheated[Oracle1] = true;
        }

       // check the Oracle2's result
       if (hasDeliver[Oracle2] == true && TrustResult == result2){
            Cheated[Oracle2] = false;
        } else {
          Cheated[Oracle2] = true;
        }
        
        bool isdone;
        
       //both cheated
       if (Cheated[Oracle1] == true && Cheated[Oracle2] == true){

         //punish both Oracles
         isdone = Client.send(2*(wage+deposit));
         
         //for debugging
         if(!isdone){
            return Done = 1112;
         }else{
            Done = 1;
         }
       }       
       // no one cheated
       else if(Cheated[Oracle1] == false && Cheated[Oracle2] == false){
           

         //pay Oracle1
         isdone = Oracle1.send(wage+deposit);
         //for debugging
         if(!isdone){
            return Done = 2221;
         }
         
         //pay Oracle2
         isdone = Oracle2.send(wage+deposit);
         //for debugging
         if(!isdone){
            return Done = 2222;
         }

          Done = 2;
      }
      // Oracle1 Cheated
      else if (Cheated[Oracle1] == true && Cheated[Oracle2] == false){
         //pay Oracle2
         isdone = Oracle2.send(wage+2*deposit-Thirdcost);
         //for debugging
         if(!isdone){
            return Done = 3331;
         }
        //pay the client
         isdone = Client.send(wage+Thirdcost);
         //for debugging
         if(!isdone){
            return Done = 3332;
         }

        Done = 3;
        }

      //Oracle2 cheated
      else if (Cheated[Oracle1] == false && Cheated[Oracle2] == true){
         //pay Oracle1
         isdone = Oracle1.send(wage+2*deposit-Thirdcost);
         //for debugging
         if(!isdone){
            return Done = 4441;
         }
        //pay the client
         isdone = Client.send(wage+Thirdcost);
         //for debugging
         if(!isdone){
            return Done = 4442;
         }

          Done = 4;
      }

        //pay the Trust Oracle
        isdone = TrustOracle.send(Thirdcost);
        
        //for debugging
        if(!isdone){
            return Done = 5555;
        }
        Done = 5;
        
        state = State.Done;
        return Done;
        
    }//end DISPUTE

     //Seventh Function TIMER
    function Timer() returns (bool Time){
        uint T = now;
        bool succ;
        //The oracle timed out and the deposit was not submitted before T1.The transaction was abandoned.
        if ((T>=T1) && state == State.Created){
           //refund the client
           succ= Client.send(2*wage+Thirdcost);
           require(succ);
           
           //refund other party who has paid
            if (hasBid[Oracle1]==true){
                succ= Oracle1.send(deposit);
                require(succ);
            }
            if (hasBid[Oracle2]==true){
                succ= Oracle2.send(deposit);
                require(succ);
            }
            
            state = State.Aborted;

        //The Oracle timed out and did not submit data results before T2.
        //End the deliver function early and settle the amount    
        }else if ((T>=T2) && state == State.GetData){
            //move to pay state
            state = State.Pay;

        //If T>T3, and the client neither pays nor raises a dispute, 
        //for the oracle that delivered the result before T2, pay the wage and refund the deposit
        //any remaining money will be transferred to the client.
        }else if ((T>=T3) && state == State.Pay){
            //pay who has delivered a result
            if(hasDeliver[Oracle1] == true){
               succ= Oracle1.send(wage+deposit);
               require(succ);
            }
            if(hasDeliver[Oracle2] == true){
               succ= Oracle2.send(wage+deposit);
               require(succ);
            }
            //rest goes to the client
           succ= Client.send(this.balance);
           require(succ);
           state = State.Done;
           
        }

    }

    function reset() returns (bool){
      require(msg.sender == Client);
      require(state == State.Done||state==State.Aborted);
      
      delete results[Oracle1];
      delete results[Oracle2];
      
      delete hasBid[Oracle1];
      delete hasBid[Oracle2];
      delete Cheated[Oracle1];
      delete Cheated[Oracle2];
      delete hasDeliver[Oracle1];
      delete hasDeliver[Oracle2];

      Oracle1=0;
      Oracle2=0;
      TrustOracle=0;
      
      wage = 0; Thirdcost = 0; deposit = 0; T1 =0; T2 = 0; T3 = 0;

      state = State.INIT;

      if (!Client.send(address(this).balance)){
          return false;
        }
    }

     //return the result of TrustOracle
    function getTrustResult() returns (uint Trustresult){
        Trustresult = TrustResult;
    }
    
    function getCurrentBalance () public view returns (uint){
        return address(this).balance;
    }

    function getBalance(address addr) public view returns(uint){
        return address(addr).balance;
    }


}
// end Prisoner Contract
