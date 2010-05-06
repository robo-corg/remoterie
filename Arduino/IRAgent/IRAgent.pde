#include <IRremote.h>
#include <IRremoteInt.h>


#include <IRremote.h>

#define RECV_PIN    11
#define STATUS_PIN  13

IRrecv irrecv(RECV_PIN);
IRsend irsend;
decode_results results;

#define MAXMSG      300
#define EOL         '*'
char msgbuf[MAXMSG+2];
char *msg;
int msglen = 0;
int msgx = 0;

int getInt()
{
  int val = 0;
  int sz = 0;
  char ch;
  //skip leading spaces
  while (msg[msgx] == ' ')
  {
    msgx++;
  }
  // accumulate number
  while (((ch = msg[msgx]) >= '0') && (ch <= '9'))
  {
    val = val*10+(ch-'0');
    sz++;
    msgx++;
  }
  //skip delimiter
  if ((ch == ',') || (ch == ';'))
  {
    msgx++;
  } 
  // validate return value
  if (sz == 0)
  {
    // something we didn't like
    Serial.print("Unxpected data at ");
    Serial.println(msgx,DEC);
    Serial.println(ch,HEX);
    Serial.println(&msg[msgx-1]);
    return -1;
  }
  else
  {
    return val;
  }
}

long getHex()
{
  long val = 0;
  int sz = 0;
  char ch;
  //skip leading spaces
  while (msg[msgx] == ' ')
  {
    msgx++;
  }
  // accumulate value
  while (true)
  {
    ch = msg[msgx];
    if ((ch >= '0') && (ch <= '9'))
    {
      val = (val<<4)|(ch-'0');
      sz++;
      msgx++;
    } else
    if ((ch >= 'a') && (ch <='f'))
    {
      val = (val<<4)|(ch-'a'+0xa);
      sz++;
      msgx++;
    } else
    if ((ch >= 'A') && (ch <='F'))
    {
      val = (val<<4)|(ch-'A'+0xa);
      sz++;
      msgx++;
    }
    else
    {
      // not a hex character
      break;
    }
  }
  //skip delimiter
  if ((ch == ',') || (ch == ';'))
  {
    msgx++;
  } 
  // validate return value
  if (sz == 0)
  {
    // something we didn't like
    Serial.print("Unxpected data at ");
    Serial.println(msgx,DEC);
    Serial.println(ch,HEX);
    Serial.println(&msg[msgx-1]);
    return -1;
  }
  else
  {
    return val;
  }
}

void performCapture()
{
  unsigned long expire;
  int t;
  irrecv.enableIRIn();
  irrecv.resume();
  // allow 10 second wait
  expire = millis()+10000;
  while (expire > millis()) 
  {
    if (irrecv.decode(&results))
    {
      Serial.println("Captured signal");
      // return results
      switch (results.decode_type)
      {
      case NEC:
      case SONY:
      case DISH:
      case SHARP:
      case PANASONIC:
      case MOTOROLA:
      case DENON:
      case SAMSUNG:
        Serial.print("se");
        Serial.print(results.decode_type,DEC);
        Serial.print(",");
        Serial.print(results.address,HEX);
        Serial.print(",");
        Serial.print(results.bits,DEC);
        Serial.print(",");
        Serial.print(results.value,HEX);
        Serial.println("*");
        return;
      default:
        Serial.print("sr38,");
        for (int i = 1; i <= results.rawlen-1; i++)
        {
          if (i&1)
          {
            t = results.rawbuf[i]*USECPERTICK-MARK_EXCESS;
            Serial.print(t,DEC);
            Serial.print(",");
          }
          else
          {
            t = results.rawbuf[i]*USECPERTICK-MARK_EXCESS;
            Serial.print(t,DEC);
            Serial.print(";");
          }
        }
        Serial.println("0*");
        return;
      }
    }
    else
    {
      // nothing to return, signal error
      delay(50);
    }
  }
  if (expire != 0)
    {
      Serial.println("No signal received");
    }
}

void performSend()
{
  msgx = 2;
  switch (msg[1])
  {
  case 'r':
    performSendRaw();
    break;
  case 'e':
    performSendEncoded();
    break;
  default:
    Serial.print("Unknown send type: ");
    Serial.println(msg[1]);
    break;
  }
}

void performSendEncoded()
{
  int type;
  unsigned long address;
  int datalen;
  unsigned long data;
  type = getInt();
  address = getHex();
  datalen = getInt();
  data = getHex();
  switch (type)
  {
  case NEC:
    irsend.sendNEC(data,datalen);
    irsend.sendNEC(REPEAT,0);
    break;
  case SONY:
    for (int rep = 0; rep < 3; rep++)
    {
    irsend.sendSony(data,datalen);
    }
    break;
  case DISH:
    irsend.sendDISH(data,datalen);
    break;
  case SHARP:
    irsend.sendSharp(data,datalen);
    break;
  case PANASONIC:
    irsend.sendPanasonic(address,data);
    break;
  case MOTOROLA:
    for (int rep = 0; rep < 2; rep++)
    {
      irsend.sendMotorola(data,datalen);
    }
    break;
  case DENON:
    for (int rep = 0; rep < 3; rep++)
    {
      // three times
      irsend.sendDenon(data,datalen);
      // complement last 10 bits
      data = (data & 0x7c00) | ((~data) & 0x3ff);
    }
    break;
  case SAMSUNG:
    irsend.sendSamsung(data,datalen);
    break;
  default:
    Serial.print("Uknown type: ");
    Serial.println(type,DEC);
    return;
  }
  Serial.println("Encoded command sent");
}
  
  
void performSendRaw()
{
  int hz,t;
  hz = getInt();
  if (hz <= 0)
  {
    Serial.println("Invalid hz");
    return;
  }
  irsend.enableIROut(hz);
  while (msgx < msglen-1) 
  {
    t = getInt();
    if (t < 0)
    {
      Serial.println("Invalid mark");
      return;
    }
    irsend.mark(t);
    t = getInt();
    if (t < 0)
    {
      Serial.println("Invalid space");
      return;
    }
    irsend.space(t);
  }
  Serial.println("Command sent");
}
  

void processMsg()
{
  //Serial.print(msgbuf[0],HEX);
  //Serial.println(msg[MAXMSG],HEX);
  switch (msg[0])
  {
  case 'c':
    // initiate capture
    performCapture();
    break;
  case 's':
    // send sequence
    performSend();
    break;
  default:
    Serial.print("Unknown command: ");
    Serial.println(msg[0],HEX);
    Serial.println(msg);
    break;
  }
  msglen = 0;
  //Serial.print(msgbuf[0],HEX);
  //Serial.println(msg[MAXMSG],HEX);
  return;
}
  

void setup()
{
  Serial.begin(115200);
  irrecv.enableIRIn();
  pinMode(STATUS_PIN,OUTPUT);
  Serial.println("IRAgent ready");
  msg = &msgbuf[1];
  msgbuf[0] = 's';
  msg[MAXMSG] = 'S';
}

void loop()
{
  char ch;
  if (Serial.available())
  {
    ch = Serial.read();
    if (ch == EOL)
    {
      processMsg();
      Serial.flush();
    } else
    if (msglen < MAXMSG)
    {
      msg[msglen++] = ch;
    }
    else
    {
      msglen--;
      Serial.println("Msg overflow");
    }
  }
}
  


