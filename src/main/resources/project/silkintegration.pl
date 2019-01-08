# -----------------------------------------------------------------------------

# -------------------------------------------------------------------------
# Package
#    silkintegration.pl
#
# Purpose
#   A perl script called from an ElectricCommander step that calls the
#   Borland Silk Central API and ElectricCommander API to run tests
#
# plugin version
#    1.0
# Dependencies
#    Requires Perl with specific modules
#        Time::Local
#        Getopt::Long
#        silkapi.pm
#        ElectricCommander.pm
#        ecarguments.pl
# Date
#    03/02/2010
#
# Engineer
#    Brian Nelson
#
# Copyright (c) 2011 Electric Cloud, Inc.
# All rights reserved

# ----------------
#
# Includes
#
# ----------------
use FindBin;
use File::Spec;
use strict;
use lib "$FindBin::Bin";
use Time::Local;
use Getopt::Long;
use ElectricCommander;
use ElectricCommander::PropDB;
use ElectricCommander::PropMod;
use warnings;
use SOAP::Lite (  maptype => {} ); 
use SilkCentral;

# Turn off output buffering:
$| = 1;
# -------------------------------------------------------------------------
# Globals
# -------------------------------------------------------------------------

$::gExitCode    = 0;                         # used to bubble exit code up
@::gLoadFiles = ();                 # additional perl files to load

%::gOptions = (

   "load=s" => \@::gLoadFiles,
      );

# -----------------------------------------------------------------------
#  loadPluginFiles
#    Load and execute plugin perl files specified by --load option.
#
#  Results:
#    returns nothing
#
#  Side Effects:
#    runs arbitrary perl code and may exit
#
#  Arguments:
#    None
#------------------------------------------------------------------------
sub loadPluginFiles() {

    foreach my $file (@::gLoadFiles) {
        $file = File::Spec->rel2abs($file);
        if ( !( do $file ) ) {
            my $message = $@;
            if ( !$message ) {

                # If the file isn't found no message is left in $@,
                # but there is a message in $!.
                $message = "Cannot read file \"$file\": " . lcfirst($!);
            }
            die $message;
        }
    }
}

sub main() {

    if (!GetOptions(%::gOptions)) {
        exit(1);
    }

    loadPluginFiles;


    exit($::gExitCode);
}


main();
