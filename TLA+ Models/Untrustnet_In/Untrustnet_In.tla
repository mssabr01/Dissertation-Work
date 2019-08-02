------------------------------ MODULE Untrustnet_In ------------------------------

EXTENDS Sequences,
        Naturals,
        EncapPacket,
        TLC,
        ASCII,
        FiniteSets,
        Modbus
        
LOCAL INSTANCE Hex
    WITH natValue <- 0, hexValue <- <<0>> 
    
LOCAL Range(T) == { T[x] : x \in DOMAIN T }

MessagesToSerialPort == \*these are in ASCII but they are converted to decimal before being used below. See StrTupleToNumTuple in ASCII.tla
    { StrTupleToNumTuple(isEncap),
      StrTupleToNumTuple(<<"!","J","G","P","9","4","3","2","J","3","9","J","G","W","I","R","W">>),
      StrTupleToNumTuple(<<"!","\r","\n">>),
      StrTupleToNumTuple(<<"J","G","P","9","4","3","2","J","3","9","J","G","W","I","R","W","\r","\n">>),
      StrTupleToNumTuple(<<"!","1","1","0","3","0","0","6","B","0","0","0","3","7","E","\r","\n">>),
      StrTupleToNumTuple(<<"!","1","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R",
                           "L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L",
                           "1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1",
                           "0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0",
                           "3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3",
                           "0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0",
                           "0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0",
                           "6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6",
                           "B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B",
                           "0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0",
                           "0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0",
                           "0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0",
                           "3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3",
                           "7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7",
                           "E","C","R","1","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E",
                           "C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C",
                           "R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R",
                           "L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L",
                           "1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1",
                           "0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0",
                           "3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3",
                           "0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0",
                           "0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0",
                           "6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6",
                           "B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B",
                           "0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0",
                           "0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0",
                           "0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0",
                           "3","7","E","C","G","L","F","1","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0",
                           "0","3","7","E","C","R",
                           "L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L",
                           "1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1",
                           "0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0",
                           "3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3",
                           "0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0",
                           "0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0",
                           "6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6",
                           "B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B",
                           "0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0",
                           "0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0",
                           "0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0",
                           "3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3",
                           "7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7",
                           "E","C","R","1","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E",
                           "C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C",
                           "R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R",
                           "L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L",
                           "1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1",
                           "0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0",
                           "3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3",
                           "0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0",
                           "0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0",
                           "6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6",
                           "B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B",
                           "0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0",
                           "0","0","3","7","E","C","R","L","1","0","3","0","0","6","B","0","0","0","3","7","E","C">>),
      StrTupleToNumTuple(<<"!","1","1","0","3","0","0","6","B","0","0","0">> \o isEncap), \*this one starts a new modbus packet half way through the message
      <<>>,<<1>>,<<2>>,<<3>>,<<4>>,<<5>>,<<6>>,<<7>>,<<8>>,<<9>>,<<10>>,<<11>>,<<12>>,<<13>>, \* all possible values
      <<14>>,<<15>>,<<16>>,<<17>>,<<18>>,<<19>>,<<20>>,<<21>>,<<22>>,<<23>>,<<24>>,<<25>>,   \*that could come across the serial line
      <<26>>,<<27>>,<<28>>,<<29>>,<<30>>,<<31>>,<<32>>,<<33>>,<<34>>,<<35>>,<<36>>,<<37>>,<<38>>,<<39>>,<<40>>,<<41>>,
      <<42>>,<<43>>,<<44>>,<<45>>,<<46>>,<<47>>,<<48>>,<<49>>,<<50>>,<<51>>,<<52>>,<<53>>,<<54>>,<<55>>,<<56>>,<<57>>,
      <<58>>,<<59>>,<<60>>,<<61>>,<<62>>,<<63>>,<<64>>,<<65>>,<<66>>,<<67>>,<<68>>,<<69>>,<<70>>,<<71>>,<<72>>,<<73>>,
      <<74>>,<<75>>,<<76>>,<<77>>,<<78>>,<<79>>,<<80>>,<<81>>,<<82>>,<<83>>,<<84>>,<<85>>,<<86>>,<<87>>,<<88>>,<<89>>,
      <<90>>,<<91>>,<<92>>,<<93>>,<<94>>,<<95>>,<<96>>,<<97>>,<<98>>,<<99>>,<<100>>,<<101>>,<<102>>,<<103>>,<<104>>,<<105>>,
      <<106>>,<<107>>,<<108>>,<<109>>,<<110>>,<<111>>,<<112>>,<<113>>,<<114>>,<<115>>,<<116>>,<<117>>,<<118>>,<<119>>,<<120>>,<<121>>,
      <<122>>,<<123>>,<<124>>,<<125>>,<<126>>,<<127>>,<<128>>,<<129>>,<<130>>,<<131>>,<<132>>,<<133>>,<<134>>,<<135>>,<<136>>,<<137>>,
      <<138>>,<<139>>,<<140>>,<<141>>,<<142>>,<<143>>,<<144>>,<<145>>,<<146>>,<<147>>,<<148>>,<<149>>,<<150>>,<<151>>,<<152>>,<<153>>,
      <<154>>,<<155>>,<<156>>,<<157>>,<<158>>,<<159>>,<<160>>,<<161>>,<<162>>,<<163>>,<<164>>,<<165>>,<<166>>,<<167>>,<<168>>,<<169>>,
      <<170>>,<<171>>,<<172>>,<<173>>,<<174>>,<<175>>,<<176>>,<<177>>,<<178>>,<<179>>,<<180>>,<<181>>,<<182>>,<<183>>,<<184>>,<<185>>,
      <<186>>,<<187>>,<<188>>,<<189>>,<<190>>,<<191>>,<<192>>,<<193>>,<<194>>,<<195>>,<<196>>,<<197>>,<<198>>,<<199>>,<<200>>,<<201>>,
      <<202>>,<<203>>,<<204>>,<<205>>,<<206>>,<<207>>,<<208>>,<<209>>,<<210>>,<<211>>,<<212>>,<<213>>,<<214>>,<<215>>,<<216>>,<<217>>,
      <<218>>,<<219>>,<<220>>,<<221>>,<<222>>,<<223>>,<<224>>,<<225>>,<<226>>,<<227>>,<<228>>,<<229>>,<<230>>,<<231>>,<<232>>,<<233>>,
      <<234>>,<<235>>,<<236>>,<<237>>,<<238>>,<<239>>,<<240>>,<<241>>,<<242>>,<<243>>,<<244>>,<<245>>,<<246>>,<<247>>,<<248>>,<<249>>,
      <<250>>,<<251>>,<<252>>,<<253>>,<<254>>,<<255>>
      }


(*--fair algorithm Untrustnet_In
variables   rxBuf = <<>>,
            rx = FALSE,
            rxReg = <<>>,
            msgid = <<>>,
            msg = <<>>,
            incomingMessages \in MessagesToSerialPort,
            incByte = <<>>,
            last2 = <<0,0>>,
            guid = <<0>>,
            modchkBuffer = <<>>, \*this is what is passed to crypto.
            verifyBuffer = <<>>  \*this is what is passed to modchk.
begin

\* wait for something to appear in the buffer
untrustnet_in1:   while Len(incomingMessages) > 0 do
                   
                        ti1: msg := incomingMessages;
                        ti2: incomingMessages := <<>>;
                start:  while Len(msg) > 0 do                 \*while there are bytes left in the message

                inc:    if Len(msg) > 1 then                    \*pop off head of message
                            incByte :=  <<Head(msg)>>;
                            msg := Tail(msg);
                        else
                            incByte := <<msg[1]>>;
                            msg := <<>>;
                        end if;
                        
                        rxReg := incByte;    
                        
                        receive:    \* a ":" character indicates the start of a new message
                        if rxReg = StrTupleToNumTuple(<<"!">>)
                                then rxBuf := rxReg; \*restart the buffer essentially
                        end if;
                         
                        \*if the buffer is full then there is NO WAY it could be valid modbus
                        if Len(rxBuf) = MAXENCAPSIZE then
             buffull:       rxBuf := <<>>;
                            rxReg := <<>>;
                            incByte := <<>>;
                            last2 := <<0,0>>;
                            goto start;
                        end if;
                        
                        \*only put character in buffer is there is already a ":" in it.
                        \*buffer can only start with ":" so if its empty then just discard character
            buffProp:   if Len(rxBuf) > 0 /\ ~(rxReg =StrTupleToNumTuple(<<"!">>)) then
                            r0: last2 := Tail(last2 \o rxReg); \*update last2
                            r1: rxBuf := rxBuf \o rxReg; \* put the contents of the register into the buffer
                        end if;
                        
                        \*empty the register
                        r2: rxReg := <<>>;
                        
            check:     \*if we get the end of the modbus "\r\n" then ship it
                        if NumTupleToStrTuple(last2) = <<"\r","\n">> then \*convert back to ASCII before checking for end of packet
                            if(Len(rxBuf)) >= MINENCAPSIZE then
                                check0: msgid := <<guid[1]>> \o <<"u","n","i">>;
                                check1: guid[1] := guid[1] + 1;
                                check2: modchkBuffer := Append(modchkBuffer, [id|->msgid, text|->GetModbus(rxBuf), source|->"untrustnet_in"]);
                                verifyBuffer := Append(verifyBuffer, [id|->msgid, text|->GetModbus(rxBuf)]);
                                \*check2: send("messagecheck", [id|->msgid, text|->rxBuf, source|->"trustnet_in"]);
                                \*        send("sign", [id|->msgid, text|->rxBuf]);
                            end if;
                            check4: rxBuf := <<>>;
                            rxReg := <<>>;
                            incByte := <<>>;
                            last2 := <<0,0>>;
                        end if;
                end while;
            end while;

end algorithm
*)

\* BEGIN TRANSLATION
VARIABLES rxBuf, rx, rxReg, msgid, msg, incomingMessages, incByte, last2, 
          guid, modchkBuffer, verifyBuffer, pc

vars == << rxBuf, rx, rxReg, msgid, msg, incomingMessages, incByte, last2, 
           guid, modchkBuffer, verifyBuffer, pc >>

Init == (* Global variables *)
        /\ rxBuf = <<>>
        /\ rx = FALSE
        /\ rxReg = <<>>
        /\ msgid = <<>>
        /\ msg = <<>>
        /\ incomingMessages \in MessagesToSerialPort
        /\ incByte = <<>>
        /\ last2 = <<0,0>>
        /\ guid = <<0>>
        /\ modchkBuffer = <<>>
        /\ verifyBuffer = <<>>
        /\ pc = "untrustnet_in1"

untrustnet_in1 == /\ pc = "untrustnet_in1"
                  /\ IF Len(incomingMessages) > 0
                        THEN /\ pc' = "ti1"
                        ELSE /\ pc' = "Done"
                  /\ UNCHANGED << rxBuf, rx, rxReg, msgid, msg, 
                                  incomingMessages, incByte, last2, guid, 
                                  modchkBuffer, verifyBuffer >>

ti1 == /\ pc = "ti1"
       /\ msg' = incomingMessages
       /\ pc' = "ti2"
       /\ UNCHANGED << rxBuf, rx, rxReg, msgid, incomingMessages, incByte, 
                       last2, guid, modchkBuffer, verifyBuffer >>

ti2 == /\ pc = "ti2"
       /\ incomingMessages' = <<>>
       /\ pc' = "start"
       /\ UNCHANGED << rxBuf, rx, rxReg, msgid, msg, incByte, last2, guid, 
                       modchkBuffer, verifyBuffer >>

start == /\ pc = "start"
         /\ IF Len(msg) > 0
               THEN /\ pc' = "inc"
               ELSE /\ pc' = "untrustnet_in1"
         /\ UNCHANGED << rxBuf, rx, rxReg, msgid, msg, incomingMessages, 
                         incByte, last2, guid, modchkBuffer, verifyBuffer >>

inc == /\ pc = "inc"
       /\ IF Len(msg) > 1
             THEN /\ incByte' = <<Head(msg)>>
                  /\ msg' = Tail(msg)
             ELSE /\ incByte' = <<msg[1]>>
                  /\ msg' = <<>>
       /\ rxReg' = incByte'
       /\ pc' = "receive"
       /\ UNCHANGED << rxBuf, rx, msgid, incomingMessages, last2, guid, 
                       modchkBuffer, verifyBuffer >>

receive == /\ pc = "receive"
           /\ IF rxReg = StrTupleToNumTuple(<<"!">>)
                 THEN /\ rxBuf' = rxReg
                 ELSE /\ TRUE
                      /\ rxBuf' = rxBuf
           /\ IF Len(rxBuf') = MAXENCAPSIZE
                 THEN /\ pc' = "buffull"
                 ELSE /\ pc' = "buffProp"
           /\ UNCHANGED << rx, rxReg, msgid, msg, incomingMessages, incByte, 
                           last2, guid, modchkBuffer, verifyBuffer >>

buffull == /\ pc = "buffull"
           /\ rxBuf' = <<>>
           /\ rxReg' = <<>>
           /\ incByte' = <<>>
           /\ last2' = <<0,0>>
           /\ pc' = "start"
           /\ UNCHANGED << rx, msgid, msg, incomingMessages, guid, 
                           modchkBuffer, verifyBuffer >>

buffProp == /\ pc = "buffProp"
            /\ IF Len(rxBuf) > 0 /\ ~(rxReg =StrTupleToNumTuple(<<"!">>))
                  THEN /\ pc' = "r0"
                  ELSE /\ pc' = "r2"
            /\ UNCHANGED << rxBuf, rx, rxReg, msgid, msg, incomingMessages, 
                            incByte, last2, guid, modchkBuffer, verifyBuffer >>

r0 == /\ pc = "r0"
      /\ last2' = Tail(last2 \o rxReg)
      /\ pc' = "r1"
      /\ UNCHANGED << rxBuf, rx, rxReg, msgid, msg, incomingMessages, incByte, 
                      guid, modchkBuffer, verifyBuffer >>

r1 == /\ pc = "r1"
      /\ rxBuf' = rxBuf \o rxReg
      /\ pc' = "r2"
      /\ UNCHANGED << rx, rxReg, msgid, msg, incomingMessages, incByte, last2, 
                      guid, modchkBuffer, verifyBuffer >>

r2 == /\ pc = "r2"
      /\ rxReg' = <<>>
      /\ pc' = "check"
      /\ UNCHANGED << rxBuf, rx, msgid, msg, incomingMessages, incByte, last2, 
                      guid, modchkBuffer, verifyBuffer >>

check == /\ pc = "check"
         /\ IF NumTupleToStrTuple(last2) = <<"\r","\n">>
               THEN /\ IF (Len(rxBuf)) >= MINENCAPSIZE
                          THEN /\ pc' = "check0"
                          ELSE /\ pc' = "check4"
               ELSE /\ pc' = "start"
         /\ UNCHANGED << rxBuf, rx, rxReg, msgid, msg, incomingMessages, 
                         incByte, last2, guid, modchkBuffer, verifyBuffer >>

check4 == /\ pc = "check4"
          /\ rxBuf' = <<>>
          /\ rxReg' = <<>>
          /\ incByte' = <<>>
          /\ last2' = <<0,0>>
          /\ pc' = "start"
          /\ UNCHANGED << rx, msgid, msg, incomingMessages, guid, modchkBuffer, 
                          verifyBuffer >>

check0 == /\ pc = "check0"
          /\ msgid' = <<guid[1]>> \o <<"u","n","i">>
          /\ pc' = "check1"
          /\ UNCHANGED << rxBuf, rx, rxReg, msg, incomingMessages, incByte, 
                          last2, guid, modchkBuffer, verifyBuffer >>

check1 == /\ pc = "check1"
          /\ guid' = [guid EXCEPT ![1] = guid[1] + 1]
          /\ pc' = "check2"
          /\ UNCHANGED << rxBuf, rx, rxReg, msgid, msg, incomingMessages, 
                          incByte, last2, modchkBuffer, verifyBuffer >>

check2 == /\ pc = "check2"
          /\ modchkBuffer' = Append(modchkBuffer, [id|->msgid, text|->GetModbus(rxBuf), source|->"untrustnet_in"])
          /\ verifyBuffer' = Append(verifyBuffer, [id|->msgid, text|->GetModbus(rxBuf)])
          /\ pc' = "check4"
          /\ UNCHANGED << rxBuf, rx, rxReg, msgid, msg, incomingMessages, 
                          incByte, last2, guid >>

Next == untrustnet_in1 \/ ti1 \/ ti2 \/ start \/ inc \/ receive \/ buffull
           \/ buffProp \/ r0 \/ r1 \/ r2 \/ check \/ check4 \/ check0 \/ check1
           \/ check2
           \/ (* Disjunct to prevent deadlock on termination *)
              (pc = "Done" /\ UNCHANGED vars)

Spec == /\ Init /\ [][Next]_vars
        /\ WF_vars(Next)

Termination == <>(pc = "Done")

\* END TRANSLATION

\*receive buffer never overflows
SAF1 == Len(rxBuf) <= MAXENCAPSIZE 
\*sending buffer never overflows
SAF2 == 
    /\ \A x \in Range(verifyBuffer) : Len(x.text) < MAXENCAPSIZE
    /\ \A x \in Range(modchkBuffer) : Len(x.text) < MAXENCAPSIZE
\*last2 buffer always less than 3
SAF3 == Len(last2) < 3
\*only well-formed modbus gets forwarded
SAF4 == 
    /\ \A x \in Range(verifyBuffer) : IsWellformedModbus(NumTupleToStrTuple(x.text))
    /\ \A x \in Range(modchkBuffer) : IsWellformedModbus(NumTupleToStrTuple(x.text))
\*each message that is forwarded has a unique message id
SAF5 == 
    /\ \A x \in Range(verifyBuffer) : Cardinality({y \in Range(verifyBuffer) : x.id = y.id}) = 1
    /\ \A x \in Range(modchkBuffer) : Cardinality({y \in Range(modchkBuffer) : x.id = y.id}) = 1
\*well-formed messages get sent to both inner components
SAF6 == 
    /\ \A x \in Range(verifyBuffer) : \E y \in Range(modchkBuffer) : x.id = y.id
    /\ \A x \in Range(modchkBuffer) : \E y \in Range(verifyBuffer) : x.id = y.id
\* rxBuf is either empty or starts with ":"
SAF7 == ~(rxBuf = <<>>) => Head(rxBuf) = CharToNum(STARTCHAR)


    \* if the message is well-formed then it gets sent
LV1 == IsWellformedEncap(NumTupleToStrTuple(rxBuf)) ~> \E x \in Range(verifyBuffer) : x.text = GetModbus(rxBuf)
\*LV1 == IsWellformedEncap(NumTupleToStrTuple(msg)) ~> \E x \in Range(verifyBuffer) : x.text = msg \*this needs to be reworked
    \* all messages are processed
LV2 == <>[](incomingMessages = <<>>)
    \*last2 buffer gets reset after each well-formed message
LV3 == NumTupleToStrTuple(last2) = <<"\r","\n">> ~> last2 = <<0,0>>

=============================================================================
\* Modification History
\* Last modified Mon Jul 15 00:19:02 EDT 2019 by mehdi
\* Last modified Sun Jun 09 18:06:27 EDT 2019 by mssabr01
\* Last modified Sun May 13 21:08:28 EDT 2018 by SabraouM
\* Created Sat May 05 11:36:54 EDT 2018 by SabraouM
