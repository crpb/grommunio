# Usage and examples

## selector

Will run `temp.views` and then anything declared in `$linkname.sql`.

e.g. `ln -s $PWD/selector "${PATH%%:*}"/messagecount` will try to load the file
`$PWD/messagecount.sql` and execute it on the sqlite-db of $1 or all users.
> `for SQL in *.sql; do echo ln -s $PWD/selector "$HOME/bin/${SQL%.sql}"; done`



## `folderpermissions`

### json keys

```
folderpermissions user@dom.tld | jq ' keys, [ .result[0]| keys ] '
[
  "maildir",
  "permissions",
  "username"
]
[
  [
    "folder_hex",
    "folder_id",
    "folder_name",
    "parent_hex",
    "parent_id",
    "permission",
    "permission_hex",
    "username"
  ]
]
```

### filter on `folderpermissions`

#### Single mailbox
- username
  - default permissions
    - `folderpermissions user@dom.tld | jq ' .result[] | select ( .username | match("default") ) '`
  - match email
    - `folderpermissions user@dom.tld | jq ' .result[] | select ( .username | match( "foo@dom.tld" ) ) '`
  - match domain 
    - `folderpermissions user@dom.tld | jq ' .result[] | select ( .username | match( "@dom.tld" ) ) '`
- folder_id (int)
  - IPM_SUBTREE
    - `folderpermissions user@dom.tld | jq ' .result[] | select ( .folder_id == 9 ) '`
- folder_hex
  - IPM_SUBTREE
    - ` folderpermissions user@dom.tld | jq ' .result[] | select ( .folder_hex == "0x9" ) '`
  - Calendar
    - `folderpermissions user@dom.tld | jq ' .result[] | select ( .folder_hex == "0xf" ) '`

#### All mailboxes + modified array
- folder_hex
  - IPM_SUBTREE 
    - `folderpermissions  | jq ' { mailbox: .username, permissions: [ .result[] | select ( .folder_hex == "0x9" ) ] } '`
  - Freebusy Data
    - `folderpermissions  | jq ' { mailbox: .username, permissions: [ .result[] | select ( .folder_hex == "0x18" ) ] } '`
- Permission(decimal)
  - > 2048
    - `folderpermissions  | jq ' { mailbox: .username, permissions: [ .result[] | select ( .permission_dec >= 2048 ) ] } '`
- Foldername
  - Foldername LIKE "%Customer-X%"
    - `folderpermissions  | jq ' { mailbox: .username, permissions: [ .result[] | select ( .folder_name | match("Customer-X" ) ) ] } '`

## `messagecount`

```
 # messagecount server@moo.tld |jq
{
    "username": "server@moo.tld",
        "maildir": "/var/lib/gromox/user/1/3",
        "permissions": [
        {
            "id": 13,
            "folder": "Inbox",
            "COUNT": 1885
        },
        {
            "id": 15,
            "folder": "Calendar",
            "COUNT": 4
        },
        {
            "id": 19,
            "folder": "Contacts",
            "COUNT": 1
        },
        {
            "id": 2106081,
            "folder": "2024",
            "COUNT": 1094
        }
    ]
}

