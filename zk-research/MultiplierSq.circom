// zk-research/MultiplierSq.circom
pragma circom 2.0.0;

template MultiplierSq() {
   
    signal input a;
    signal input b;
    signal output c;

    c <== a * b;
}

//电路的入口
component main = MultiplierSq();