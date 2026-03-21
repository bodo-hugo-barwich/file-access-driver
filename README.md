# File::Access::Driver

File::Access::Driver - Library to access files in an easy and straight forward way

This library is full fleshed "_batteries included_" solution 
to ease up the work with files.

It does not crash but instead reports errors in the in-built error report.

On writing the files if directories do not exist they will be created automatically.

On reading when a file does not exist it does not produce an exception but an empty
string. But in the error report it can be seen, that the file did not exist.

# Features

Some important Features are:
- Automatic file creation on write
- Persistent file access (instead of opening and closing constantly)
- Resilent design (reading on non existing files does not crash)
- In-built error report 
- Avoids copy-in-memory operations

# Usage

The `File::Access::Driver` can be used as seen in the "_File Write_" test:

```perl
        use File::Access::Driver;

        my $driver = File::Access::Driver->new( 'filepath' => $spath . 'files/out/testfile_out.txt' );

        # Make sure the file does not exist
        is( $driver->Delete(), 1, "File Delete: Delete operation 1 correct" );
        is( $driver->Exists(), 0, "File Exist: File does not exist anymore" );

        $driver->writeContent(q(This is the multi line content for the test file.

It will be written into the test file.
The file should only contain this text.
Also the file should be created.
));

        printf(
            "Test File Exists - File '%s': Write finished with [%d]\n",
            $driver->getFileName(),
            $driver->getErrorCode()
        );
        printf(
            "Test File Exists - File '%s': Write Report:\n'%s'\n",
            $driver->getFileName(),
            ${ $driver->getReportString() }
        );
        printf(
            "Test File Exists - File '%s': Write Error:\n'%s'\n",
            $driver->getFileName(),
            ${ $driver->getErrorString() }
        );

        is( $driver->getErrorCode(),        0,  "Write Error Code: No errors have occurred" );
        is( ${ $driver->getErrorString() }, '', "Write Error Message: No errors are reported" );

        is( $driver->Exists(), 1, "File Exist: File does exist now" );
        isnt( $driver->getFileSize(), 0, "File Size: File is not empty anymore" );

```