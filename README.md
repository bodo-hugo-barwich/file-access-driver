# File::Access::Driver

File::Access::Driver - Library to access files in an easy and straight forward way

This library is full fleshed "_batteries included_" solution 
to ease up the work with files.

It does not crash but instead reports errors in the in-built error report.

# Features

Some important Features are:
- Automatic file creation on write
- Persistent file access (instead of opening and closing constantly)
- Resilent design (reading on non existing files does not crash)
- In-built error report 
- Avoids copy-in-memory operations