RECENTLY CHANGED .. EXAMPLES MOSTLY OUTDATED

# Usage and examples

## selector

Will run `temp.views` and then anything declared in `$linkname.sql`.

e.g. `ln -s $PWD/selector "${PATH%%:*}"/messagecount will try to load the file
`$PWD/messagecount.sql` and execute it on the sqlite-db of $1 or all users.
> `for SQL in *.sql; do echo ln -s $PWD/selector "$HOME/bin/${SQL%.sql}"; done`



## `folderpermissions`

### json structure

```
{
  "folderpermissions": [
    {
      "mailbox": "server@clownflare.de",
      "maildir": "/var/lib/gromox/user/clownflare.de/server",
      "result": [
        {
          "folder_id": 15,
          "parent_id": 9,
          "folder_hex": "0xf",
          "parent_hex": "0x9",
          "foldername": "Calendar",
          "username": "default",
          "permissions": "foldervisible,freebusysimple",
          "permission": null,
          "permission_dec": 3072,
          "permission_hex": "0xc00"
        },
        {
          "folder_id": 24,
          "parent_id": 1,
          "folder_hex": "0x18",
          "parent_hex": "0x1",
          "foldername": "Freebusy Data",
          "username": "default",
          "permissions": "freebusysimple",
          "permission": "freebusysimple",
          "permission_dec": 2048,
          "permission_hex": "0x800"
        }
      ]
    }
  ]
}

```

### filter on `folderpermissions`

#### Single mailbox
- username
  - default permissions
    - `folderpermissions user@dom.tld | jq ' .[] | .permissions[] | select ( .username | match("default") ) '`
  - match email
    - `folderpermissions user@dom.tld | jq ' .[] | .permissions[] | select ( .username | match( "foo@dom.tld" ) ) '`
  - match domain 
    - `folderpermissions user@dom.tld | jq ' .[] | .permissions[] | select ( .username | match( "@dom.tld" ) ) '`
- folder_id (int)
  - IPM_SUBTREE
    - `folderpermissions user@dom.tld | jq ' .[] | .permissions[] | select ( .folder_id == 9 ) '`
- folder_hex
  - IPM_SUBTREE
    - ` folderpermissions user@dom.tld | jq ' .[] | .permissions[] | select ( .folder_hex == "0x9" ) '`
  - Calendar
    - `folderpermissions user@dom.tld | jq ' .[] | .permissions[] | select ( .folder_hex == "0xf" ) '`

#### All mailboxes
- Split in array/folder
  - `folderpermissions  | jq ' .folderpermissions |  map( { mailbox, maildir, permissions: .result[] } ) '`
- folder_hex
  - IPM_SUBTREE 
    - `folderpermissions  | jq ' .folderpermissions |  map( { mailbox, maildir, permissions: .result[] | select ( .folder_hex == "0x9" ) } ) '`
  - Freebusy Data
    - `folderpermissions  | jq ' .folderpermissions |  map( { mailbox, maildir, permissions: .result[] | select ( .folder_hex == "0x18" ) } ) '`
- Permission(decimal) (return everything)
  - > 2048
    - `folderpermissions  | jq ' { mailbox: .username, permissions: [ .permissions[] | select ( .permission_dec >= 2048 ) ] } '`
- Foldername
  - Foldername LIKE "%Customer-X%"
    - `folderpermissions  | jq ' { mailbox: .username, permissions: [ .permissions[] | select ( .folder_name | match("Customer-X" ) ) ] } '`
- Foldername + Parent
  - Foldername LIKE "%Customer%" and subdirectory of Inbox
    - `folderpermissions  | jq ' { mailbox: .username, permissions: [ .permissions[] | select ( ( .folder_name | match( "Customer" ) ) and ( .parent_hex == "0xd" ) ) ] } '`

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
```
```
# sum of messages (be aware that might look into folders you don't wanna count)
# messagecount server@moo.tld | jq ' [.result [] |.count]| add ' 
21012
```
