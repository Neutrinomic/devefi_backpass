import IcrcReader "mo:devefi-icrc-reader";
import IcrcSender "mo:devefi-icrc-sender";
import Principal "mo:base/Principal";
import Timer "mo:base/Timer";
import Nat64 "mo:base/Nat64";

actor class() = this {

    let ledger_id = Principal.fromText("mxzaz-hqaaa-aaaar-qaada-cai");
    var actor_principal : ?Principal = null;
    var next_tx_id : Nat64 = 0;

    // Sender 
    stable let icrc_sender_mem = IcrcSender.Mem();

    let icrc_sender = IcrcSender.Sender({
        ledger_id;
        mem = icrc_sender_mem;
        onError = func (e: Text) {}; // In case a cycle throws an error
        onConfirmations = func (confirmations: [Nat64]) {
            // handle confirmed ids
        };
        onCycleEnd = func (instructions: Nat64) {}; // used to measure how much instructions it takes to send transactions in one cycle
    });
    
    // Reader

    stable let icrc_reader_mem = IcrcReader.Mem();

    let icrc_reader = IcrcReader.Reader({
        mem = icrc_reader_mem;
        ledger_id;
        start_from_block = #last;
        onError = func (e: Text) {}; // In case a cycle throws an error
        onCycleEnd = func (instructions: Nat64) {}; // returns the instructions the cycle used. 
                                                    // It can include multiple calls to onRead
        onRead = func (transactions: [IcrcReader.Transaction]) {
            icrc_sender.confirm(transactions);
            // do something here
            // basically the main logic of the vector
            // we are going to send tokens back to the sender
            let fee = icrc_sender.get_fee();
            let ?me = actor_principal else return;
            label txloop for (tx in transactions.vals()) {
                let ?tr = tx.transfer else continue txloop;
                if (tr.to.owner == me) {
                    if (tr.amount <= fee) continue txloop; // ignore it
                    icrc_sender.send(next_tx_id, {
                        to = tr.from;
                        amount = tr.amount;
                        from_subaccount = tr.to.subaccount;
                    });
                    next_tx_id += 1;
                }
            }
        };
    });


    // ---


    system func postupgrade() {
        let actor_principal = Principal.fromActor(this);
        icrc_sender.start(actor_principal); // We can't call start from the constructor because this is not defined yet
        icrc_reader.start();
    }

}