# -----------------------------------------------------------------------------

# -------------------------------------------------------------------------
# Package
#    SilkCentral.pm
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
# Copyright (c) 2010 Electric Cloud, Inc.
# All rights reserved

# -----------------------------------------------------------------------------

package SilkCentral;

# -------------------------------------------------------------------------


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


# -------------------------------------------------------------------------
# Globals
# -------------------------------------------------------------------------
$::gProgramName = "silkintegration";    # program name for errors
$::gExitCode    = 0;                         # used to bubble exit code up
$::gStepName= "";                                # step name
$::gProcName= "";                                # procedure name
$::gProjName= "";                                # project name
$::gSilkResource   = "-1";                   # Silk Central Resource
$::gSilkPort       = "19124";                # Silk Central Port
$::gNoTimeStamps   = 1;                      # dont show times for now
@::gConfigList  = ();                   # stores list of VM's
$::gJobStepId   = "";                   # JobStepId requesting run test
$::gDebug       = 2;                    # debug level. higher gives more detail
# -------------------------------------------------------------------------
# Connection to the web service
# -------------------------------------------------------------------------
$::gSILKPERLServer= "localhost";    # Silk Central server
$::gSILKPERLPass= "pass";           # Password for Silk Central server
$::gSILKPERLService= "sccsystem";   # Silk Central Web Service Name
$::gDebug = 2;
$::gSchema = "";
$::gUri = "";
$::gProxy = "";
$::gNoTimeStamps = 1;             # no time stamps for now
# -------------------------------------------------------------------------



# -------------------------------------------------------------------------
# Table of commands and parameters
#
# cmd           - the command to run
# arg           - list of required arguments
# retFld        - the root of XML return to pass to valueof()
# retType    
#    SCALAR     - a single value (string or numeric)
#    NONE       - this call does not return a value
#    RECORD     - this call returns one record
# retRec        - record structure (fields)
#
# -------------------------------------------------------------------------

%::gCommands =  (
        "logonUser" =>
        {     cmd =>     "logonUser", 
              arg =>     ["username", "password"],
          retFld =>  "logonUserReturn",
          retType => "SCALAR",
          retRec =>  [ "sessionId" ],
        },
        "getProjects" => 
        {     cmd =>     "getProjects", 
              arg =>     ["sessionId"],
          retFld =>  "getProjectsReturn",
          retType => "RECORD",
          retRec =>  [ "description" , "id", "name" ],
        },
        "getCurrentProject" => 
        {     cmd =>     "getCurrentProject", 
              arg =>     ["sessionId"],
          retFld =>  "getCurrentProjectReturn",
          retType => "RECORD",
          retRec =>  [ "description", "id", "name" ],
        },
        "queueExecution" =>
        {     cmd =>     "queueExecution", 
              arg =>     ["sessionID", "executionDefID", "version", "build", "execServerHostName", "execServerPort", "runProperties"],
          retFld =>  "queueExecutionReturn",
          retType => "SCALAR",
          retRec =>  [ "execTimestamp" ],
        },
        "getExecutionResult" =>
        {     cmd =>     "getExecutionResult", 
              arg =>     ["sessionID", "executionDefID", "executionTimestamp", "execServerHostName", "execServerPort"],
          retFld =>  "getExecutionResultReturn",
          retType => "RECORD",
          retRec =>  [ "duration", "errors", "id", "name", "status", "testRunId", "type", "typeId", "warnings" ],
        },
        "getExecutionResultURL" =>
        {     cmd =>     "getExecutionResultURL", 
              arg =>     ["sessionID", "executionDefID", "executionTimestamp", "execServerHostName", "execServerPort"],
          retFld =>  "getExecutionResultURLReturn",
          retType => "SCALAR",
          retRec =>  [ "resultURLReturnCode" ],
        },
    );


###############################
# new - Object constructor for SilkCentral
#
# Arguments:
#   cmdr - ElectricCommander object
#   opts - hash
#
# Returns:
#   none
#
################################
sub new { 
    my $class = shift; 
    my $self = { 
        _cmdr    => shift,
        _opts    => shift,
    }; 
    bless $self, $class; 
}

###############################
# myCmdr - Get ElectricCommander instance
#
# Arguments:
#   none
#
# Returns:
#   ElectricCommander instance
#
################################
sub myCmdr {
    my ($self) = @_;
    return $self->{_cmdr};
}

###############################
# opts - Get opts hash
#
# Arguments:
#   none
#
# Returns:
#   opts hash
#
################################
sub opts {
    my ($self) = @_;
    return $self->{_opts};
}

# -----------------------------------------------------------------------
#  runSilkTest
#    Execute a Silk Test
#
#  Results:
#      returns nothing
#
#  Side Effects:
#
#  Arguments:
#    None
#
#------------------------------------------------------------------------
sub runSilkTest() {

    my ($self) = @_;

    my %result;

    # ----------------------------------------
    # Initialize SOAP API
    # ----------------------------------------
    $self->Initialize( "sccsystem", $::gDebug );

    # -------------------------------------------------
    # Connect to Commander and Get Properties
    # -------------------------------------------------

        $::gStepName = $self->getProp( "stepName", { "jobStepId" => $::gJobStepId } );
        $::gProcName =
          $self->getProp( "procedureName", { "jobStepId" => $::gJobStepId } );
        $::gProjName =
          $self->getProp( "projectName", { "jobStepId" => $::gJobStepId } );

        my $propPrefix =
            "/projects["
          . $::gProjName
          . "]/procedures["
          . $::gProcName . "]"
          . "/steps["
          . $::gStepName
          . "]/ec_customEditorData";

        ## if not set by input options, get from properties
        if ( $self->opts->{testExecutionId} eq "-1" ) {
            $self->opts->{testExecutionId} = $self->getProp( $propPrefix . "/testExecutionId" );
        }
        if ( $self->opts->{version} eq "-1" ) {
            $self->opts->{version} = $self->getProp( $propPrefix . "/version" );
        }
        if ( $self->opts->{build} eq "-1" ) {
            $self->opts->{build}= $self->getProp( $propPrefix . "/build" );
        }
        if ( $::gSilkResource eq "-1" ) {
            $::gSilkResource = $self->getProp( $propPrefix . "/resource" );
        }

    if ( $::gSilkResource eq "" ) {
        $::gSilkResource = "localhost";
    }
    $self->debugMsg( 2, "Silk Test Execution Id:" . $self->opts->{testExecutionId} );
    $self->debugMsg( 2, "Silk Test Version:" . $self->opts->{version} );
    $self->debugMsg( 2, "Silk Test Build Number:" . $self->opts->{build} );
    $self->debugMsg( 2, "Silk Test Build Resource:" . $::gSilkResource );

    # -------------------------------------------------
    # Logon Session to Silk Central
    # -------------------------------------------------
    %result = $self->CallSilkCentral(
        "logonUser",
        (
            "username" => $self->opts->{silkCentral_user},
            "password" => $self->opts->{silkCentral_pass}
        )
    );
    my $session = $result{"value"};
    $self->debugMsg( 2, "Silk Central Session ID:" . $session );

    # ----------------------------------------
    # Re-Initialize SOAP API for tmplanning service
    # ----------------------------------------
    $self->Initialize("tmplanning", $::gDebug );

    # ----------------------------------------
    # Start Test Execution
    # ----------------------------------------
    %result = $self->CallSilkCentral(
        "queueExecution",
        (
            "sessionID"        => $session,
            executionDefID     => $self->opts->{testExecutionId},
            version            => $self->opts->{version},
            build              => $self->opts->{build},
            execServerHostName => $::gSilkResource,
            execServerPort     => $::gSilkPort,
            runProperties      => ""
        )
    );

    # process errors
    if ( $result{"faultcode"} ) {
        $self->debugMsg( 0,
                "Error: "
              . $result{"faultcode"} . " "
              . $result{"faultstring"} . " "
              . $result{"faultdetail"} );
        $::gExitCode = $result{"faultcode"};
        return;
    }
    my $time = $result{"value"};
    $self->debugMsg( 2, "Silk Central Execution Timestamp: " . $time );

    # ----------------------------------------
    # Get Execution Result URL
    # - Loop until test finished by checking for execRunId value
    # ----------------------------------------
    my $runstr = "";
    while ( !( $runstr =~ m/execRunId/ ) ) {
        %result = $self->CallSilkCentral(
            "getExecutionResultURL",
            (
                sessionID          => $session,
                executionDefID     => $self->opts->{testExecutionId},
                executionTimestamp => $time,
                execServerHostName => $::gSilkResource,
                execServerPort     => $::gSilkPort
            )
        );

        # process errors
        if ( $result{"faultcode"} ) {
            $self->debugMsg( 0,
                    "Error: "
                  . $result{"faultcode"} . " "
                  . $result{"faultstring"} . " "
                  . $result{"faultdetail"} );
            $::gExitCode = $result{"faultcode"};
            return;
        }
        $runstr = $result{"value"};
        $self->debugMsg( 5, "Waiting for test. Current result=[$runstr]" );
        sleep 5;
    }
    $self->debugMsg( 2, "Silk Test Execution Result URL: " . $result{"value"} );

        my $setResult =
          $self->setProp( "/myJob/report-urls/Silk Test Execution Result",
            $result{"value"}, { "jobStepId" => $::gJobStepId } );


    # ----------------------------------------
    # Get Execution Results
    # ----------------------------------------
    %result = $self->CallSilkCentral(
        "getExecutionResult",
        (
            sessionID          => $session,
            executionDefID     => $self->opts->{testExecutionId},
            executionTimestamp => $time,
            execServerHostName => $::gSilkResource,
            execServerPort     => $::gSilkPort
        )
    );

    # process errors
    if ( $result{"faultcode"} ) {
        $self->debugMsg( 0,
                "Error: "
              . $result{"faultcode"} . " "
              . $result{"faultstring"} . " "
              . $result{"faultdetail"} );
        $::gExitCode = $result{"faultcode"};
        return;
    }

    # print out results
    # if there were errors or warnings postp will pick them up from the output
    my @vals = @{ $result{"value"} };
    print "\n================== Silk Test Results =====================\n\n";
    for ( my $i = 1 ; $i < @vals ; $i++ ) {
        print "Test Definition " . $i . " - \n";
        print "    Name: " . $vals[$i]->{"name"} . "\n";
        print "    Type: " . $vals[$i]->{"type"} . "\n";
        print "    Run Id: " . $vals[$i]->{"testRunId"} . "\n";
        print "    Duration: " . $vals[$i]->{"duration"} . "\n";
        print "    Status: " . $vals[$i]->{"status"} . "\n";
        if ( $vals[$i]->{"warnings"} > 0 ) {
            print "    Warning: " . $vals[$i]->{"warnings"} . "\n";
        }
        if ( $vals[$i]->{"errors"} > 0 ) {
            print "    Error: " . $vals[$i]->{"errors"} . "\n";
        }
    }
}

#-------------------------------------------------------------------------
# getProp
#
#    Get a property given an absolute property reference
#
#
# Results:
#     Returns value of the property
#
# Side Effects:
#     None.
#
# Arguments:
#    propertyName    - the source property string
#
#-------------------------------------------------------------------------
sub getProp($) {
    my ($self, @location) = @_;
    my $xPath;
    my $value = "";

    $xPath = $self->myCmdr()->getProperty(@location);
    if ( !defined $xPath ) {
        return $value;
    }
    $value = $xPath->findvalue('//value');
    my $strValue = "";
    $strValue = substr( $value, 0 );
    return $strValue;
}

#-------------------------------------------------------------------------
# setProp
#
#    set a property given an absolute property reference
#
#
# Results:
#     Returns value of the property
#
# Side Effects:
#     None.
#
# Arguments:
#    propertyName    - the source property string
#    value           - the value to set
#
#-------------------------------------------------------------------------
sub setProp($$) {
    my ($self, @arguments) = @_;
    my $xPath;
    my $value = "";

    $xPath = $self->myCmdr()->setProperty(@arguments);
    if ( !defined $xPath ) {
        return $value;
    }
    $value = $xPath->findvalue('//error');
    return $value;
}

# -----------------------------------------------------------------------
#  debugMsg
#
#    Print a debug message
#
#  Results:
#
#  Side Effects:
#    May print to STDOUT
#
#  Arguments:
#    errorlevel    - number compared to $::gDebug
#    msg          - string message
#
#------------------------------------------------------------------------
sub debugMsg($$) {
    my ( $self, $errlev, $msg ) = @_;

    my ( $date, $time ) = $self->dateStrFormat( time() );

    if ($::gNoTimeStamps) {
        if ( $::gDebug >= $errlev ) { print "$msg\n"; }
    }
    else {
        if ( $::gDebug >= $errlev ) { print "$date $time: $msg\n"; }
    }
}

# -----------------------------------------------------------------------
#  dateStrFormat
#
#    Takes in a time in epoch format and returns a date and time strings
#
#  Results:
#      returns
#        date    - string
#        time    - string
#
#  Side Effects:
#    none
#
#  Arguments:
#    ref    - (number) time in epoch format (seconds)
#
#------------------------------------------------------------------------
sub dateStrFormat($) {
    my ($self, $ref) = @_;
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      localtime($ref);
    my $date = sprintf "%d-%02d-%02d", $year + 1900, $mon + 1, $mday;
    my $time = sprintf "%d:%02d:%02d", $hour, $min, $sec;
    return ( $date, $time );
}

#########################################################################
# Silk Central SOAP Wrappers
#########################################################################:w

# -----------------------------------------------------------------------
#  Inititialize
#  
#  Results:
#
#  Side Effects:
#      initializes globals for  calls
#
#  Arguments:
#        server          -string
#        user            -string
#        pass            -string
#        webservice      -string  (e.g. sccsystem, sccentities, tmplanning)
#
#-----------------------------------------------------------------------
sub Initialize {

    my ($self, $silkPerlService) = @_;


    $::gSchema = "http://" . $self->opts->{silkCentral_url} . 
        "/services/$silkPerlService?WSDL";
    $::gUri = "http://borland.com/us/products/silk";

    # if protocol passed in, do not add one
    if (substr($self->opts->{silkCentral_url},0,5) eq "http:" or
        substr($self->opts->{silkCentral_url},0,4) eq "tcp:" or
        substr($self->opts->{silkCentral_url},0,6) eq "https:") {
        $::gProxy = $self->opts->{silkCentral_url}.  "/services/$silkPerlService";
    } else {
    $::gProxy = "http://" .
        $self->opts->{silkCentral_url}.  "/services/$silkPerlService";
    }
    $self->debugMsg(2, "Initialize server proxy=" . $::gProxy);

}

# -----------------------------------------------------------------------
#  CallSilkCentral
#  
#  Results:
#      returns result based on requested function
#        %ret 
#            value          value returned from SOAP call (scalar or array)
#            faultcode      error code (0 if no error)
#            faultstring    fault string from SOAP call
#            faultdetail    more fault detail from SOAP call
#            retType        SCALAR, NONE, RECORD
#            retFld         Name of node in return XML to parse
#            retRec         List of field names in returned record
#
#
#  Side Effects:
#
#  Arguments:
#        cmd               - string
#        args              - array of args in name => value format
#
#-----------------------------------------------------------------------
sub CallSilkCentral($%) {

    my ($self, $cmd, %argsin) = @_;

    my %ret = ();
    $ret {"value"} = "";
    $ret{"faultcode"} = 0;
    $ret{"faultstring"} = "";
    $ret{"faultdetail"} = "";

    $self->debugMsg(99, "CallSilkCentral: $cmd");

    # find command in global command table
    if (!$::gCommands{$cmd}) {
        $self->debugMsg(1, "Error: CallSilkCentral: unknown command $cmd");
    $ret{"faultcode"} = -1;
    $ret{"faultstring"} = "$cmd: unknown command";
        return (%ret);
    }
    my @cmdTableArgs = @ {$::gCommands{$cmd}{"arg"}};

    $ret{"retType"}  = $::gCommands{$cmd}{"retType"};
    $ret{"retFld"}   = $::gCommands{$cmd}{"retFld"};
    $ret{"retRec"}   = $::gCommands{$cmd}{"retRec"};

    my @soapargs = ();
    
    # for each required arg
    foreach my $arg (@cmdTableArgs) {
        # find the value in the list of args passed in
        if (! defined $argsin{$arg} ) {
            $self->debugMsg(1, "Error: required arg $arg not found");
            $ret{"faultcode"} = -2;
            $ret{"faultstring"} = "missing required argument:$arg";
            return (%ret);
        }

        # lookup value passed in for this arg
        my $value = $argsin{$arg};

        # make sure it is a string because something in the
        # perl LITE lib remembers that it was a struct
        # and creates wierd headers with <c-gensym4> tags unless
        # we pass in a string. My Perl is not good enough to know how
        # to cast this correctly, but this works.
        my $strarg = substr($arg,0);
        my $strval = substr($value,0);

        # push onto SOAP call parameters
        push @soapargs, SOAP::Data->name($strarg => $strval);
        $self->debugMsg(99, "  $arg=$value");
    }

    # call SOAP
    my $result = $self->SOAP_CALL($cmd, @soapargs);

    # on error from SOAP
    if ($result->fault) {
        $ret{"faultcode"} = $result->faultcode;
        $ret{"faultstring"} = $result->faultstring;
        $ret{"faultdetail"} = $result->faultdetail;
        return (%ret);
    };

    # parse result
    my $retFld = $ret{"retFld"};
    if ($ret{"retType"}  eq "SCALAR") {
        my $tmpScalar = $result->valueof('//' . $retFld );
        $ret{"value"} = $tmpScalar;
    return (%ret);
    }

    if ($ret{"retType"} eq "RECORD" ) {
        my @retArray = $result->valueof('//' . $retFld);
        $ret{"value"} = [ @retArray ];
    return (%ret);
    }

    # otherwise nothing to return
    return (%ret);
}


# -----------------------------------------------------------------------
#  SOAP_CALL
#    Make SOAP call to Silk Central
#  
#  Results:
#      returns array of configurations
#
#  Side Effects:
#
#  Arguments:
#    Method name
#    Arguments
#
#-----------------------------------------------------------------------
sub SOAP_CALL($$) {

    my ($self, $methodName, @args ) = @_;

    # --------------------------------------------------
    # action must be set since SILK CENTRAL SOAP server expects
    # .NET style SOAPAction $uri/method whereas 
    # SOAP::Lite defaults to $uri#method
    # --------------------------------------------------
    my $soap = SOAP::Lite
        -> proxy($::gProxy)
        -> autotype(0)
        -> on_action (sub {sprintf('"%s/%s"',$::gUri,$methodName)} )
        -> uri($::gUri);

    # -------------------------------------------------
    # Prepare method name as SOAP::Data item
    # -------------------------------------------------
    my $method = SOAP::Data->name($methodName)
            ->attr({xmlns => $::gUri});

    # -------------------------------------------------
    # Make the call
    # -------------------------------------------------
    my $result = $soap->call($method => @args);

   

    # -------------------------------------------------
    # If we are debugging, show low level faults
    # -------------------------------------------------
    if ($::gDebug > 1) {
        if ($result->fault) {
            print join ', ',
        $result->faultcode,
        $result->faultstring,
        $result->faultdetail,"\n";
        }
    }
    return $result;
}

