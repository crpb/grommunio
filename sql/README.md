# Examples

## json keys

```
exmdb-perms user@dom.tld | jq ' keys, [ .permissions[0]| keys ] '
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

## filter

### Single mailbox
- username
  - default permissions
    - `exmdb-perms user@dom.tld | jq ' .permissions[] | select ( .username | match("default") ) '`
  - match email
    - `exmdb-perms user@dom.tld | jq ' .permissions[] | select ( .username | match( "foo@dom.tld" ) ) '`
  - match domain 
    - `exmdb-perms user@dom.tld | jq ' .permissions[] | select ( .username | match( "@dom.tld" ) ) '`
- folder_id (int)
  - IPM_SUBTREE
    - `exmdb-perms user@dom.tld | jq ' .permissions[] | select ( .folder_id == 9 ) '`
- folder_hex
  - IPM_SUBTREE
    - ` exmdb-perms user@dom.tld | jq ' .permissions[] | select ( .folder_hex == "0x9" ) '`
  - Calendar
    - `exmdb-perms user@dom.tld | jq ' .permissions[] | select ( .folder_hex == "0xf" ) '`

### All mailboxes + modified array
- folder_hex
  - IPM_SUBTREE 
    - `exmdb-perms  | jq ' { mailbox: .username, permissions: [ .permissions[] | select ( .folder_hex == "0x9" ) ] } '`
  - Freebusy Data
    - `exmdb-perms  | jq ' { mailbox: .username, permissions: [ .permissions[] | select ( .folder_hex == "0x18" ) ] } '`
- Permission(decimal)
  - > 2048
    - `exmdb-perms  | jq ' { mailbox: .username, permissions: [ .permissions[] | select ( .permission_dec >= 2048 ) ] } '`
- Foldername
  - Foldername LIKE "%Customer-X%"
    - `exmdb-perms  | jq ' { mailbox: .username, permissions: [ .permissions[] | select ( .folder_name | match("Customer-X" ) ) ] } '`
- Foldername + Parent
  - Foldername LIKE "%Customer%" and subdirectory of Inbox
    `exmdb-perms  | jq ' { mailbox: .username, permissions: [ .permissions[] | select ( ( .folder_name | match( "Customer" ) ) and ( .parent_hex == "0xd" ) ) ] } '`

