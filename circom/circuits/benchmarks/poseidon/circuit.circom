pragma circom 2.0.0;

include "./poseidon_constants.circom";

template Sigma() {
    signal input in;
    signal output out;

    signal in2;
    signal in4;

    in2 <== in*in;
    in4 <== in2*in2;

    out <== in4*in;
}

template Ark(t, C, r) {
    signal input in[t];
    signal output out[t];

    for (var i=0; i<t; i++) {
        out[i] <== in[i] + C[i + r];
    }
}

template Mix(t, M) {
    signal input in[t];
    signal output out[t];

    var lc;
    for (var i=0; i<t; i++) {
        lc = 0;
        for (var j=0; j<t; j++) {
            lc += M[j][i]*in[j];
        }
        out[i] <== lc;
    }
}

template MixLast(t, M, s) {
    signal input in[t];
    signal output out;

    var lc = 0;
    for (var j=0; j<t; j++) {
        lc += M[j][s]*in[j];
    }
    out <== lc;
}

template MixS(t, S, r) {
    signal input in[t];
    signal output out[t];


    var lc = 0;
    for (var i=0; i<t; i++) {
        lc += S[(t*2-1)*r+i]*in[i];
    }
    out[0] <== lc;
    for (var i=1; i<t; i++) {
        out[i] <== in[i] +  in[0] * S[(t*2-1)*r + t + i -1];
    }
}

template PoseidonEx(nInputs, nOuts) {
    signal input inputs[nInputs];
    signal input initialState;
    signal output out[nOuts];

    // Using recommended parameters from whitepaper https://eprint.iacr.org/2019/458.pdf (table 2, table 8)
    // Generated by https://extgit.iaik.tugraz.at/krypto/hadeshash/-/blob/master/code/calc_round_numbers.py
    // And rounded up to nearest integer that divides by t
    var N_ROUNDS_P[16] = [56, 57, 56, 60, 60, 63, 64, 63, 60, 66, 60, 65, 70, 60, 64, 68];
    var t = nInputs + 1;
    var nRoundsF = 8;
    var nRoundsP = N_ROUNDS_P[t - 2];
    var C[t*nRoundsF + nRoundsP] = POSEIDON_C(t);
    var S[  N_ROUNDS_P[t-2]  *  (t*2-1)  ]  = POSEIDON_S(t);
    var M[t][t] = POSEIDON_M(t);
    var P[t][t] = POSEIDON_P(t);

    component ark[nRoundsF];
    component sigmaF[nRoundsF][t];
    component sigmaP[nRoundsP];
    component mix[nRoundsF-1];
    component mixS[nRoundsP];
    component mixLast[nOuts];


    ark[0] = Ark(t, C, 0);
    for (var j=0; j<t; j++) {
        if (j>0) {
            ark[0].in[j] <== inputs[j-1];
        } else {
            ark[0].in[j] <== initialState;
        }
    }

    for (var r = 0; r < nRoundsF\2-1; r++) {
        for (var j=0; j<t; j++) {
            sigmaF[r][j] = Sigma();
            if(r==0) {
                sigmaF[r][j].in <== ark[0].out[j];
            } else {
                sigmaF[r][j].in <== mix[r-1].out[j];
            }
        }

        ark[r+1] = Ark(t, C, (r+1)*t);
        for (var j=0; j<t; j++) {
            ark[r+1].in[j] <== sigmaF[r][j].out;
        }

        mix[r] = Mix(t,M);
        for (var j=0; j<t; j++) {
            mix[r].in[j] <== ark[r+1].out[j];
        }

    }

    for (var j=0; j<t; j++) {
        sigmaF[nRoundsF\2-1][j] = Sigma();
        sigmaF[nRoundsF\2-1][j].in <== mix[nRoundsF\2-2].out[j];
    }

    ark[nRoundsF\2] = Ark(t, C, (nRoundsF\2)*t );
    for (var j=0; j<t; j++) {
        ark[nRoundsF\2].in[j] <== sigmaF[nRoundsF\2-1][j].out;
    }

    mix[nRoundsF\2-1] = Mix(t,P);
    for (var j=0; j<t; j++) {
        mix[nRoundsF\2-1].in[j] <== ark[nRoundsF\2].out[j];
    }


    for (var r = 0; r < nRoundsP; r++) {
        sigmaP[r] = Sigma();
        if (r==0) {
            sigmaP[r].in <== mix[nRoundsF\2-1].out[0];
        } else {
            sigmaP[r].in <== mixS[r-1].out[0];
        }

        mixS[r] = MixS(t, S, r);
        for (var j=0; j<t; j++) {
            if (j==0) {
                mixS[r].in[j] <== sigmaP[r].out + C[(nRoundsF\2+1)*t + r];
            } else {
                if (r==0) {
                    mixS[r].in[j] <== mix[nRoundsF\2-1].out[j];
                } else {
                    mixS[r].in[j] <== mixS[r-1].out[j];
                }
            }
        }
    }

    for (var r = 0; r < nRoundsF\2-1; r++) {
        for (var j=0; j<t; j++) {
            sigmaF[nRoundsF\2 + r][j] = Sigma();
            if (r==0) {
                sigmaF[nRoundsF\2 + r][j].in <== mixS[nRoundsP-1].out[j];
            } else {
                sigmaF[nRoundsF\2 + r][j].in <== mix[nRoundsF\2+r-1].out[j];
            }
        }

        ark[ nRoundsF\2 + r + 1] = Ark(t, C,  (nRoundsF\2+1)*t + nRoundsP + r*t );
        for (var j=0; j<t; j++) {
            ark[nRoundsF\2 + r + 1].in[j] <== sigmaF[nRoundsF\2 + r][j].out;
        }

        mix[nRoundsF\2 + r] = Mix(t,M);
        for (var j=0; j<t; j++) {
            mix[nRoundsF\2 + r].in[j] <== ark[nRoundsF\2 + r + 1].out[j];
        }

    }

    for (var j=0; j<t; j++) {
        sigmaF[nRoundsF-1][j] = Sigma();
        sigmaF[nRoundsF-1][j].in <== mix[nRoundsF-2].out[j];
    }

    for (var i=0; i<nOuts; i++) {
        mixLast[i] = MixLast(t,M,i);
        for (var j=0; j<t; j++) {
            mixLast[i].in[j] <== sigmaF[nRoundsF-1][j].out;
        }
        out[i] <== mixLast[i].out;
    }

}

template Poseidon(nInputs) {
    signal input inputs[nInputs];
    signal output out;

    component pEx = PoseidonEx(nInputs, 1);
    pEx.initialState <== 0;
    for (var i=0; i<nInputs; i++) {
        pEx.inputs[i] <== inputs[i];
    }
    out <== pEx.out[0];
}

component main {public[inputs]} = Poseidon(2);

//./scripts/run_circuit.sh circuits/benchmarks/poseidon/circuit.circom poseidon inputs/benchmarks/poseidon/input.json phase1/powersOfTau28_hez_final_16.ptau res.csv poseidon_output
