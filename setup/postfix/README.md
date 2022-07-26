# postfix relayhost with plain auth after tls

### e.g. Mailcow https://mailcow.email

#### `postconf`

Add additional Config-Settings for Postfix here.  
Each is line is executed with `postconf $line`


#### `postfix.sh`
``` shell
export RELAYHOST=myrelayserver
export RELAYUSER=myrelaysender
export RELAYPASS=myrelaypass
./postfix.sh
```

The relayhost will be set as `[$RELAYHOST]:submission`

## Happy Relaying!
