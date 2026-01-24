#
# @author Bodo (Hugo) Barwich
# @version 2023-03-28
# @package File Access Driver
# @subpackage lib/File/Access/Driver.pm

# This module defines the base class of the application
#
#---------------------------------
# Requirements:
#
#---------------------------------
# Extensions:
#
#---------------------------------
# Configurations:
#
#---------------------------------
# Features:

#==============================================================================
# The File::Access::Driver Package

package File::Access::Driver;

#----------------------------------------------------------------------------
#Dependencies

use Fcntl ':flock';    # import LOCK_* constants
use File::Path qw(make_path);

#----------------------------------------------------------------------------
#Constructors

sub new {

    #Take the Method Parameters
    my ( $invocant, %hshprms ) = @_;
    my $class = ref($invocant) || $invocant;
    my $self  = undef;

    #Set the Default Attributes and assign the initial Values
    $self = {
        '_file'           => undef,
        '_directory_name' => '',
        '_file_name'      => '',

        #A Reference to the Content Text
        '_file_content'       => undef,
        '_file_content_lines' => undef,
        '_file_time'          => -1,
        '_file_access_time'   => -1,
        '_file_size'          => -1,
        '_package_size'       => 32768,
        '_buffered'           => 0,
        '_persistent'         => 0,
        '_locked'             => 0,
        '_writable'           => 0,
        '_appendable'         => 0,
        '_report'             => '',
        '_error_message'      => '',
        '_error_code'         => 0
    };

    #Bestow Objecthood
    bless $self, $class;

    #print "in: '" . join(", ", @_) . "'\n";
    #print "hsh prms: '"; foreach (keys %hshprms) { print "'$_' => '$hshprms{$_}'; "} print "'\n";

    if ( scalar( keys %hshprms ) > 0 ) {
        $self->setFileDirectory( $hshprms{'filedirectory'} ) if ( defined $hshprms{'filedirectory'} );
        $self->setFileName( $hshprms{'filename'} )           if ( defined $hshprms{'filename'} );
        $self->setFilePath( $hshprms{'filepath'} )           if ( defined $hshprms{'filepath'} );
    }    #if(scalar(keys %hshprms) > 0)

    #Give the Object back
    return $self;
}

sub DESTROY {
    my $self = $_[0];

    #Free the System Resources
    $self->freeResources;
}

#----------------------------------------------------------------------------
#Administration Methods

sub setFileDirectory {
    my $self = $_[0];

    if ( scalar(@_) > 1 ) {
        $self->{'_directory_name'} = $_[1];
    }
    else    #No Parameter given
    {
        $self->{'_directory_name'} = '';
    }

    $self->{'_directory_name'} = '' unless ( defined $self->{'_directory_name'} );

    if ( $self->{'_directory_name'} ne '' ) {
        $self->{'_directory_name'} .= '/' unless ( $self->{'_directory_name'} =~ qr#/$# );
    }

    #Clear the File Object
    $self->Clear;

}

sub setFileName {
    my $self = $_[0];

    if ( scalar(@_) > 1 ) {
        $self->{'_file_name'} = $_[1];
    }
    else    #No Parameter given
    {
        $self->{'_file_name'} = '';
    }

    $self->{'_file_name'} = '' unless ( defined $self->{'_file_name'} );

    #Clear the File Object
    $self->Clear;
}

sub setFilePath {
    my $self   = $_[0];
    my $sdirnm = $_[1] || '';
    my $sflnm  = '';

    if ( $sdirnm ne '' ) {
        if ( index( $sdirnm, '/' ) > -1 ) {
            if ( $sdirnm =~ qr#(.*/)([^/]+)$# ) {
                $sdirnm = $1;
                $sflnm  = $2;
            }
        }
        else     #The Path does not include a Slash Sign
        {
            $sflnm  = $sdirnm;
            $sdirnm = '';
        }
    }

    #Set the Parsed Values
    $self->setFileDirectory($sdirnm);
    $self->setFileName($sflnm);
}

sub changeFileName {
    my $self   = $_[0];
    my $sdirnm = '';
    my $sflnm  = $_[1] || '';
    my $irs    = 0;

    if ( $sflnm ne '' ) {

        #If File Name contains Directory Information
        if ( index( $sflnm, '/' ) > -1 ) {
            if ( $sflnm =~ qr#(.*/)([^/]+)$# ) {
                $sdirnm = $1;
                $sflnm  = $2;
            }
        }

        #Assume the same Directory
        $sdirnm = $self->{'_directory_name'}
          if ( $sdirnm eq '' );

        if ( $self->Exists ) {
            $irs = rename $self->{'_directory_name'} . $self->{'_file_name'}, $sdirnm . $sflnm;

            if ($irs) {

                #Update the File Access Object accordingly but keep the Report History

                $self->{'_directory_name'} = $sdirnm;
                $self->{'_file_name'}      = $sflnm;
            }
            else    #Change File Name failed
            {
                $irs = 0 + $!;

                $self->{'_error_message'} .=
                    "File '"
                  . $self->{'_directory_name'}
                  . $self->{'_file_name'}
                  . "': Change File Name failed with [$irs]!"
                  . "Message: '$!'\n";
                $self->{'_error_code'} = 1 if ( $self->{'_error_code'} < 1 );

                $irs = 0;
            }
        }
        else     #File does not exist
        {
            $self->{'_error_message'} .= "File does not exist!\n";
            $self->{'_error_code'} = 3 if ( $self->{'_error_code'} < 1 );
        }
    }
    else         #New File Name was not given
    {
        $self->{'_error_message'} .= "New File Name is not set!\n";
        $self->{'_error_code'} = 3 if ( $self->{'_error_code'} < 1 );
    }

    return $irs;
}

sub setContent {
    my $self = $_[0];

    $self->{'_file_content'}       = undef;
    $self->{'_file_content_lines'} = undef;
    $self->{'_buffered'}           = 1 unless ( $self->{'_buffered'} );

    if ( scalar(@_) > 1 ) {
        if ( ref( $_[1] ) eq '' ) {
            $self->{'_file_content'} = \$_[1];
        }
        else {
            $self->{'_file_content'} = $_[1];
        }
    }

    ${ $self->{'_file_content'} } = ''
      unless ( defined $self->{'_file_content'} );

}

sub setContentArray {
    my $self = $_[0];

    ${ $self->{'_file_content'} } = '';
    $self->{'_file_content_lines'} = undef;
    $self->{'_buffered'}           = 1 unless ( $self->{'_buffered'} );

    if ( scalar(@_) > 1 ) {
        if ( ref( $_[1] ) eq '' ) {
            $self->{'_file_content_lines'} = \$_[1];
        }
        else {
            $self->{'_file_content_lines'} = $_[1];
        }
    }
}

sub setFileTime {
    my $self  = $_[0];
    my $itmfl = $_[1] || time;
    my $irs   = 0;

    if ( $self->Exists ) {
        $self->getFileTime;

        $irs = utime $self->{'_file_access_time'}, $itmfl, $self->{'_directory_name'} . $self->{'_file_name'};

        if ( $irs < 1 ) {
            $irs = 0 + $!;

            $self->{'_error_message'} .=
                "File '"
              . $self->{'_directory_name'}
              . $self->{'_file_name'}
              . "': Set File Time failed with [$irs]!"
              . "Message: '$!'\n";
            $self->{'_error_code'} = 1 if ( $self->{'_error_code'} < 1 );

            $irs = 0;
        }
    }
    else     #File does not exist
    {
        $self->{'_error_message'} .= "File does not exist!\n";
        $self->{'_error_code'} = 3 if ( $self->{'_error_code'} < 1 );
    }

    return $irs;
}

sub setBuffered {
    my $self = $_[0];

    if ( scalar(@_) > 1 ) {
        if ( $_[1] =~ qr/^\d+$/ ) {

            #The Parameter is an unsigned whole Number

            if ( $_[1] != 0 ) {
                $self->{'_buffered'} = 1;
            }
            else {
                $self->{'_buffered'} = 0;
            }
        }
        else    #The Parameter is not a Number
        {
            $self->{'_buffered'} = 0;
        }
    }
    else        #No Parameter was given
    {
        $self->{'_buffered'} = 1;
    }
}

sub setPersistent {
    my $self = $_[0];

    if ( scalar(@_) > 1 ) {
        if ( $_[1] =~ qr/^\d+$/ ) {

            #The Parameter is an unsigned whole Number

            if ( $_[1] != 0 ) {
                $self->{'_persistent'} = 1;
            }
            else {
                $self->{'_persistent'} = 0;
            }
        }
        else    #The Parameter is not a Number
        {
            $self->{'_persistent'} = 0;
        }
    }
    else        #No Parameter was given
    {
        $self->{'_persistent'} = 1;
    }
}

sub Create {
    my $self = $_[0];

    return $self->writeContent('');
}

sub _openrFile {
    my $self = $_[0];
    my $irs  = 0;

    if ( $self->_isOpen() ) {

        #Reopen the File in shared Reading Mode
        $self->_closeFile() if ( $self->_isWritable() );
    }    #if($self->_isOpen())

    unless ( $self->_isOpen() ) {
        if ( $self->Exists() ) {

            #Open the File
            $irs = open $self->{'_file'}, '<', $self->{'_directory_name'} . $self->{'_file_name'};

            if ( defined $irs ) {
                $irs = flock( $self->{'_file'}, LOCK_SH );

                if ($irs) {
                    $self->{'_locked'} = 1;

                    $irs = 1;
                }    #if($irs)
            }
            else     #The File could not be opened
            {
                $self->{'_error_message'} .=
                    "File '"
                  . $self->{'_directory_name'}
                  . $self->{'_file_name'} . "': "
                  . "Open Read failed!\n"
                  . "Message: '$!'\n";
                $self->{'_error_code'} = 1 if ( $self->{'_error_code'} < 1 );

                $irs = 0;
            }        #unless(defined $irs)
        }
        else         #The File does not exist
        {
            $self->{'_error_message'} .=
                "File '"
              . $self->{'_directory_name'}
              . $self->{'_file_name'} . "': "
              . "Open Read failed!\n"
              . "Message: 'File does not exist.'\n";
            $self->{'_error_code'} = 3 if ( $self->{'_error_code'} < 1 );
        }
    }
    else             #The File is open and in Reading Mode
    {
        $irs = 1;
    }

    return $irs;
}

sub _openwFile {
    my $self = $_[0];
    my $irs  = 0;

    unless ( $self->_isWritable() ) {
        $self->_closeFile() if ( $self->_isOpen() );

        if ( $self->{'_directory_name'} ne '' ) {
            unless ( -d $self->{'_directory_name'} ) {
                my $idircnt = -1;

                $self->{"_report"} .=
                    "Directory '"
                  . $self->{'_directory_name'} . "': "
                  . "Directory does not exist. Directory creating ...\n";

                #Clear any previous Error Messages
                $@ = '';

                eval {
                    #Create the Directory
                    $idircnt = make_path( $self->{'_directory_name'}, { mode => 0775 } );
                };

                if ($@) {
                    $self->{'_error_message'} .=
                        "Directory '"
                      . $self->{'_directory_name'} . "': "
                      . "Create Directory failed.\n"
                      . "Message (Code '"
                      . ( $! + 0 )
                      . "'): '$@'\n";

                    $self->{'_error_code'} = 1 if ( $self->{'_error_code'} < 1 );

                    $idircnt = -1;
                }

                $irs = 1 if ( $idircnt != -1 );
            }
            else     # Directory does exist
            {
                $irs = 1;
            }
        }
        else         #The File Directory is not set
        {
            $irs = 1;
        }

        if ($irs) {
            if ( $self->{'_file_name'} ne '' ) {

                #Open the File
                $irs = open $self->{'_file'}, ">", $self->{'_directory_name'} . $self->{'_file_name'};

                if ( defined $irs ) {
                    $self->{'_writable'} = 1;

                    $irs = flock( $self->{'_file'}, LOCK_EX );

                    if ($irs) {
                        $self->{'_locked'} = 1;

                        $irs = 1;
                    }
                }
                else     #The File could not be opened
                {
                    $self->{'_error_message'} .=
                        "File '"
                      . $self->{'_directory_name'}
                      . $self->{'_file_name'}
                      . "': Open Write failed!\n"
                      . "Message: '$!'\n";
                    $self->{'_error_code'} = 1 if ( $self->{'_error_code'} < 1 );

                    $irs = 0;
                }
            }
            else         #The File Name isnt set
            {
                $self->{'_error_message'} .= "File Name isn't set!\n";
                $self->{'_error_code'} = 3 if ( $self->{'_error_code'} < 1 );

                $irs = 0;
            }
        }
    }
    else     #The File is already open in Appending Mode
    {
        $irs = 1;
    }        #unless($self->_isWritable())

    return $irs;
};

sub _openaFile {
    my $self = $_[0];
    my $irs  = 0;

    unless ( $self->_isAppendable() ) {
        $self->_closeFile() if ( $self->_isOpen() );

        if ( $self->{'_directory_name'} ne '' ) {
            unless ( -d $self->{'_directory_name'} ) {
                my $idircnt = -1;

                #Clear any previous Error Messages
                $@ = '';

                eval {
                    #Create the Directory
                    $idircnt = make_path( $self->{'_directory_name'}, { mode => 0775 } );
                };

                if ($@) {
                    $self->{'_error_message'} .=
                        "Directory '"
                      . $self->{'_directory_name'} . "': "
                      . "Create Directory failed.\n"
                      . "Message (Code '"
                      . ( 0 + $! )
                      . "'): '$@'\n";

                    $self->{'_error_code'} = 1 if ( $self->{'_error_code'} < 1 );

                    $idircnt = -1;
                }

                $irs = 1 if ( $idircnt != -1 );
            }
            else     # Directory does exist
            {
                $irs = 1;
            }
        }
        else         #The File Directory is not set
        {
            $irs = 1;
        }

        if ($irs) {
            if ( $self->{'_file_name'} ne '' ) {

                #Open the File
                $irs = open $self->{'_file'}, ">>", $self->{'_directory_name'} . $self->{'_file_name'};

                if ( defined $irs ) {
                    $self->{'_writable'}   = 1;
                    $self->{'_appendable'} = 1;

                    $irs = flock( $self->{'_file'}, LOCK_EX );

                    $irs = seek( $self->{'_file'}, 0, SEEK_END ) if ($irs);

                    if ($irs) {
                        $self->{'_locked'} = 1;

                        $irs = 1;
                    }
                }
                else     #The File could not be opened
                {
                    $self->{'_error_message'} .=
                        "File '"
                      . $self->{'_directory_name'}
                      . $self->{'_file_name'}
                      . "': Open Append failed!\n"
                      . "Message: '$!'\n";
                    $self->{'_error_code'} = 1 if ( $self->{'_error_code'} < 1 );

                    $irs = 0;
                }
            }
            else         #The File Name isnt set
            {
                $self->{'_error_message'} .= "File Name isn't set!\n";
                $self->{'_error_code'} = 3 if ( $self->{'_error_code'} < 1 );
            }
        }
    }
    else     #The File is already open in Appending Mode
    {
        $irs = 1;
    }        #unless($self->_isAppendable())

    return $irs;
};

sub Read {
    my $self = $_[0];
    my $irs  = 0;

    ${ $self->{'_file_content'} } = '';
    $self->{'_file_content_lines'} = undef;
    $self->{'_buffered'}           = 1 unless ( $self->{'_buffered'} );
    $self->{'_file_time'}          = -1;
    $self->{'_file_size'}          = -1;

    $self->_openrFile() if ( $self->_isWritable() );

    $self->_openrFile() unless ( $self->_isOpen() );

    if ( $self->_isOpen() ) {
        my $scntntln = '';
        my $irdcnt   = -1;

        do    #while($irdcnt);
        {
            $irdcnt = sysread( $self->{'_file'}, $scntntln, $self->{"_package_size"} );

            if ( defined $irdcnt ) {
                ${ $self->{'_file_content'} } .= $scntntln if ( $irdcnt > 0 );
            }
            else    #An Error has ocurred
            {
                $self->{'_error_message'} .=
                    "File '"
                  . $self->{'_directory_name'}
                  . $self->{'_file_name'}
                  . "': Read File failed with ["
                  . ( 0 + $! ) . "]!!"
                  . "Message: '$!'\n";
                $self->{'_error_code'} = 1 if ( $self->{'_error_code'} < 1 );
            }
        } while ($irdcnt);

        $irs = 1 unless ($!);

        if ($irs) {
            my @arrflstt = stat( $self->{'_file'} );

            if ( scalar(@arrflstt) > 0 ) {
                $self->{'_file_time'} = $arrflstt[9];
                $self->{'_file_size'} = $arrflstt[7];
            }
            else    #The File Attributes are empty
            {
                $self->{'_error_message'} .=
                  "File '" . $self->{'_directory_name'} . $self->{'_file_name'} . "': File Attributes failed!\n";
            }
        }

        if ( $self->{'_persistent'} ) {
            unless ($irs) {
                $self->{'_error_message'} .=
                    "File '"
                  . $self->{'_directory_name'}
                  . $self->{'_file_name'} . "': "
                  . "File closing because of Reading Error ...\n";

                #Close the File
                $self->_closeFile();
            }
        }
        else     #File is not persistent
        {
            #Close the File
            $self->_closeFile();
        }
    }

    return $irs;
}

sub readContent {
    my $self = $_[0];

    $self->Read();

    return $self->getContent;
}

sub readContentArray {
    my $self = $_[0];

    FileAccessDriver::Read $self;

    return $self->getContentArray;
}

sub Truncate {
    my $self = $_[0];

    return $self->writeContent('');
}

sub Write {
    my $self = $_[0];
    my $irs  = 0;

    $self->{'_buffered'}         = 1 unless ( $self->{'_buffered'} );
    $self->{'_file_time'}        = -1;
    $self->{'_file_access_time'} = -1;
    $self->{'_file_size'}        = -1;

    unless ( $self->_isWritable() ) {
        $self->_closeFile() if ( $self->_isOpen() );

        #Open the File in Write Mode
        $self->_openwFile();
    }

    if ( $self->_isWritable() ) {
        my $iwrtcnt   = -1;
        my $icntntlen = length( ${ $self->{'_file_content'} } );

        $irs = 0;

        #Write the Content Line to the File
        $iwrtcnt = syswrite( $self->{'_file'}, ${ $self->{'_file_content'} } );

        if ( defined $iwrtcnt ) {
            $irs = 1;

            if ( $iwrtcnt != $icntntlen ) {
                $self->{'_error_message'} .=
                    "File '"
                  . $self->{'_directory_name'}
                  . $self->{'_file_name'}
                  . "': '$iwrtcnt' from '$icntntlen' Bytes written.\n";
            }
        }
        else    #An Error has ocurred
        {
            $self->{'_error_message'} .=
                "File '"
              . $self->{'_directory_name'}
              . $self->{'_file_name'}
              . "': File Write failed!\n"
              . "Message: '$!'\n";
            $self->{'_error_code'} = 1 if ( $self->{'_error_code'} < 1 );
        }

        if ($irs) {
            my @arrflstt = stat( $self->{'_file'} );

            if ( scalar(@arrflstt) > 0 ) {
                $self->{'_file_time'}        = $arrflstt[9];
                $self->{'_file_access_time'} = $arrflstt[8];
                $self->{'_file_size'}        = $arrflstt[7];
            }
            else    #The File Attributes are empty
            {
                $self->{'_error_message'} .=
                  "File '" . $self->{'_directory_name'} . $self->{'_file_name'} . "': File Attributes failed!\n";
            }
        }

        if ( $self->{'_persistent'} ) {
            unless ($irs) {
                $self->{'_error_message'} .=
                    "File '"
                  . $self->{'_directory_name'}
                  . $self->{'_file_name'} . "': "
                  . "File closing because of Writing Error ...\n";

                #Close the File
                $self->_closeFile();
            }
        }
        else     #File is not persistent
        {
            #Close the File
            $self->_closeFile();
        }
    }

    return $irs;
}

sub writeContent {
    my $self = $_[0];

    $self->setContent( $_[1] );

    return FileAccessDriver::Write $self;
}

sub appendLine {
    my $self     = $_[0];
    my $rcntntln = undef;
    my $irs      = 0;

    $self->{'_file_time'} = -1;
    $self->{'_file_size'} = -1;

    if ( scalar(@_) > 1 ) {
        if ( ref( $_[1] ) ne '' ) {
            $rcntntln = $_[1];
        }
        else {
            $rcntntln = \$_[1];
        }

        if ( $$rcntntln ne '' ) {
            if ( $self->{'_buffered'} > 0 ) {
                ${ $self->{'_file_content'} } .= $$rcntntln;
            }
        }
    }

    unless ( $self->_isAppendable() ) {
        $self->_closeFile() if ( $self->_isOpen() );

        #Open the File in Appending Mode
        $self->_openaFile();
    }

    if ( $self->_isAppendable() ) {
        my $iwrtcnt   = -1;
        my $icntntlen = length($$rcntntln);

        $irs = 0;

        #Write the Content Line to the File
        $iwrtcnt = syswrite( $self->{'_file'}, $$rcntntln );

        if ( defined $iwrtcnt ) {
            $irs = 1;

            if ( $iwrtcnt != $icntntlen ) {
                $self->{'_error_message'} .=
                    "File '"
                  . $self->{'_directory_name'}
                  . $self->{'_file_name'} . "': "
                  . "'$iwrtcnt' from '$icntntlen' Bytes written.\n";
            }
        }
        else    #An Error has ocurred
        {
            $self->{'_error_message'} .=
                "File '"
              . $self->{'_directory_name'}
              . $self->{'_file_name'}
              . "': File Write failed!\n"
              . "Message: '$!'\n";
            $self->{'_error_code'} = 1 if ( $self->{'_error_code'} < 1 );
        }

        if ($irs) {
            my @arrflstt = stat( $self->{'_file'} );

            if ( scalar(@arrflstt) > 0 ) {
                $self->{'_file_time'} = $arrflstt[9];
                $self->{'_file_size'} = $arrflstt[7];
            }
            else    #The File Attributes are empty
            {
                $self->{'_error_message'} .=
                  "File '" . $self->{'_directory_name'} . $self->{'_file_name'} . "': File Attributes failed!\n";
            }
        }

        if ( $self->{'_persistent'} > 0 ) {
            unless ( $irs > 0 ) {
                $self->{'_error_message'} .=
                    "File '"
                  . $self->{'_directory_name'}
                  . $self->{'_file_name'} . "': "
                  . "File closing because of Writing Error ...\n";

                #Close the File
                $self->_closeFile();
            }
        }
        else     #File is not persistent
        {
            #Close the File
            $self->_closeFile();
        }
    }    #if($self->_isAppendable())

    return $irs;
}

sub writeLine {
    my $self = $_[0];

    return $self->appendLine( $_[1] );
}

sub Delete {
    my $self = $_[0];
    my $irs  = 0;

    #Close the Open File
    $self->_closeFile() if ( $self->_isOpen );

    if ( $self->Exists ) {
        $irs = unlink $self->{'_directory_name'} . $self->{'_file_name'};

        if ( $irs < 1 ) {
            $self->{'_error_message'} .=
                "File '"
              . $self->{'_directory_name'}
              . $self->{'_file_name'}
              . "': Delete File failed with ["
              . ( 0 + $! ) . "]!"
              . "Message: '$!'\n";
            $self->{'_error_code'} = 1 if ( $self->{'_error_code'} < 1 );

            $irs = 0;
        }
    }
    else     #The File does not exist
    {
        $irs = 0;
    }

    return $irs;
}

sub _closeFile {
    my $self = $_[0];
    my $irs  = 0;

    if ( $self->__isOpen() ) {
        if ( $self->{'_locked'} > 0 ) {
            $irs = flock( $self->{'_file'}, LOCK_UN );

            unless ($irs) {
                $self->{'_error_message'} .=
                    "File '"
                  . $self->{'_directory_name'}
                  . $self->{'_file_name'} . "': "
                  . "Lock Release failed!\n"
                  . "Message: '$!'\n";
                $self->{'_error_code'} = 1 if ( $self->{'_error_code'} < 1 );
            }
            else    #File Lock was released
            {
                $self->{'_locked'} = 0;
            }
        }

        $irs = close $self->{'_file'};

        unless ( $irs > 0 ) {
            $self->{'_error_message'} .=
                "File '"
              . $self->{'_directory_name'}
              . $self->{'_file_name'} . "': "
              . "Close failed!\n"
              . "Message: '$!'\n";
            $self->{'_error_code'} = 1 if ( $self->{'_error_code'} < 1 );
        }    #unless($irs > 0)

        $self->{'_file'}       = undef;
        $self->{'_writable'}   = 0;
        $self->{'_appendable'} = 0;

        #To Refresh on next Request
        $self->{'_file_access_time'} = -1;
        $self->{'_file_time'}        = -1;
        $self->{'_file_size'}        = -1;

    }
    else    #The File is not open
    {
        $irs = 1;
    }

    return $irs;
};

sub Clear {
    my $self = $_[0];

    #Close the Open File
    $self->_closeFile() if ( $self->_isOpen() );

    #Clear Content
    $self->{'_file_content'}       = undef;
    $self->{'_file_content_lines'} = undef;

    $self->clearErrors;

    #To Refresh on next Request
    $self->{'_file_access_time'} = -1;
    $self->{'_file_time'}        = -1;
    $self->{'_file_size'}        = -1;

}

sub clearErrors {
    my $self = $_[0];

    $self->{"_report"}        = '';
    $self->{'_error_message'} = '';
    $self->{'_error_code'}    = 0;
}

sub freeResources {
    my $self = $_[0];

    if ( $self->_isOpen ) {

        #Close the Open File
        $self->_closeFile();
    }

    $self->{'_file_content'} = undef;
}

#----------------------------------------------------------------------------
#Consultation Methods

sub getFileDirectory {
    my $self = $_[0];

    return $self->{'_directory_name'};
}

sub getFileName {
    my $self = $_[0];

    return $self->{'_file_name'};
}

sub getFilePath {
    my $self = $_[0];

    return $self->{'_directory_name'} . $self->{'_file_name'};
}

sub getContent {
    my $self = $_[0];

    ${ $self->{'_file_content'} } = ''
      unless ( defined $self->{'_file_content'} );

    if ( $self->{'_file_content'} eq '' ) {
        if ( scalar( @{ $self->{'_file_content_lines'} } ) > 0 ) {
            ${ $self->{'_file_content'} } = join( "\n", @{ $self->{'_file_content_lines'} } );
        }
    }

    return $self->{'_file_content'};
}

sub getContentArray {
    my $self = $_[0];

    @{ $self->{'_file_content_lines'} } = ()
      unless ( defined $self->{'_file_content_lines'} );

    if ( scalar( @{ $self->{'_file_content_lines'} } ) == 0 ) {
        if ( ${ $self->{'_file_content'} } ne '' ) {
            @{ $self->{'_file_content_lines'} } = split( "\n", ${ $self->{'_file_content'} } );
        }
    }

    return $self->{'_file_content_lines'};
}

sub getFileTime {
    my $self = $_[0];

    if ( $self->Exists() ) {
        if ( $self->{'_file_time'} < 0 ) {
            my @arrflstt = stat( $self->{'_directory_name'} . $self->{'_file_name'} );

            $self->{'_file_time'}        = -1;
            $self->{'_file_access_time'} = -1;
            $self->{'_file_size'}        = -1;

            if ( scalar(@arrflstt) > 0 ) {
                $self->{'_file_time'}        = $arrflstt[9];
                $self->{'_file_access_time'} = $arrflstt[8];
                $self->{'_file_size'}        = $arrflstt[7];
            }
            else    #The File Attributes are empty
            {
                $self->{'_error_message'} .=
                  "File '" . $self->{'_directory_name'} . $self->{'_file_name'} . "': File Attributes failed!\n";
                $self->{'_error_code'} = 1 if ( $self->{'_error_code'} < 1 );
            }
        }
    }
    else     #The File does not exist
    {
        $self->{'_file_time'}        = -1;
        $self->{'_file_access_time'} = -1;
        $self->{'_file_size'}        = -1;
    }

    return $self->{'_file_time'};
}

sub getFileSize {
    my $self = $_[0];

    if ( $self->Exists() ) {
        if ( $self->{'_file_size'} < 0 ) {
            my @arrflstt = stat( $self->{'_directory_name'} . $self->{'_file_name'} );

            $self->{'_file_time'}        = -1;
            $self->{'_file_access_time'} = -1;
            $self->{'_file_size'}        = -1;

            if ( scalar(@arrflstt) > 0 ) {
                $self->{'_file_time'}        = $arrflstt[9];
                $self->{'_file_access_time'} = $arrflstt[8];
                $self->{'_file_size'}        = $arrflstt[7];
            }
            else    #The File Attributes are empty
            {
                $self->{'_error_message'} .=
                  "File '" . $self->{'_directory_name'} . $self->{'_file_name'} . "': File Attributes failed!\n";
                $self->{'_error_code'} = 1 if ( $self->{'_error_code'} < 1 );
            }
        }
    }
    else     #The File does not exist
    {
        $self->{'_file_time'}        = -1;
        $self->{'_file_access_time'} = -1;
        $self->{'_file_size'}        = -1;
    }

    return $self->{'_file_size'};
}

sub Exists {
    my $self = $_[0];
    my $irs  = 0;

    unless ( $self->_isOpen() ) {
        if ( $self->{'_file_name'} ne '' ) {
            if ( $self->{'_directory_name'} ne '' ) {
                $irs = 1 if ( -d $self->{'_directory_name'} );
            }
            else    #The Directory Name isnt set
            {
                $irs = 1;
            }

            if ($irs) {
                $irs = 0 unless ( -e $self->{'_directory_name'} . $self->{'_file_name'} );
            }
        }
        else        #The File Name isnt set
        {
            $self->{'_error_message'} .= "File Name isn't set!\n";
            $self->{'_error_code'} = 3 if ( $self->{'_error_code'} < 1 );
        }
    }
    else            #The File is already open
    {
        $irs = 1;
    }

    return $irs;
}

sub _isOpen {
    my $self = $_[0];
    my $iopn = 0;

    if ( defined $self->{'_file'} ) {
        $iopn = 1 if ( fileno( $self->{'_file'} ) );
    }
    else            #The File Handle is not set
    {
        $self->{'_file'} = undef unless ( exists $self->{'_file'} );
    }

    return $iopn;
}

sub _isWritable {
    my $self = $_[0];
    my $iopn = 0;

    if ( $self->_isOpen() ) {
        $iopn = $self->{'_writable'} if ( defined $self->{'_writable'} );
    }

    return $iopn;
}

sub _isAppendable {
    my $self = $_[0];
    my $iopn = 0;

    if ( $self->_isOpen() ) {
        $iopn = $self->{'_appendable'} if ( defined $self->{'_appendable'} );
    }

    return $iopn;
}

sub isBuffered {
    return $_[0]->{'_buffered'};
}

sub isPersistent {
    return $_[0]->{'_persistent'};
}

sub getReportString {
    return \$_[0]->{"_report"};
}

sub getErrorString {
    return \$_[0]->{'_error_message'};
}

sub getErrorCode {
    return $_[0]->{'_error_code'};
}

return 1;
