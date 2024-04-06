# dbo.sp_LoginExtractor Stored Procedure

## Overview
The `sp_LoginExtractor` stored procedure is designed to extract login information, user permissions, and role memberships for a specified SQL Server login. 
This includes generating dynamic T-SQL scripts to recreate the login with the same settings, permissions, and role memberships on another server.

## Requirements
- Tested on SQL Server 2016, 2022, and Managed Instances.
- Stored Procedures:
  - `sp_help_revlogin`
  - `sp_hexadecimal`
  - `LongPrint`  
- Functions:
  - `fn_ExtractDefaultDatabase` 
  - `fn_ExtractRoleMembership` 
  - `fn_UserNameValidation` 

## Features
- Extracts user login script with hashed password using `sp_help_revlogin`.
- Dynamically generates T-SQL scripts for:
  - User creation.
  - Role memberships.
  - Database and object-level permissions.

## How to Use
1. Deploy `sp_LoginExtractor` to your master database.
2. Execute the stored procedure with the target username as a parameter:
T-SQL:
EXEC sp_LoginExtractor @UserName = 'target_login_name';
The stored procedure will print out a script that can be used to recreate the user's login, permissions, and role memberships.

Contributing
Feel free to fork this repository to propose improvements or add new features. Please ensure that any contributions adhere to best practices for security and efficiency.

