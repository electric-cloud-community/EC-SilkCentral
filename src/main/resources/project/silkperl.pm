#!/usr/bin/env perl
# -*-Perl-*-
#--------#---------#---------#---------#---------#---------#---------#-------80#

# -----------------------------------------------------------------------------
# Copyright 2007 Electric Cloud Corporation
#
#
# Package
#    silkapi.pm
#
# Purpose
#    A perl library that wraps Borland Silk Central SOAP API
#
# Dependencies
#    Requires Perl with specific modules 
#        Getopt::Long
#        SOAP::Lite
#        ElectricCommander.pm
#        and ecarguments.pl
#
# The following special keyword indicates that the "cleanup" script should
# scan this file for formatting errors, even though it doesn't have one of
# the expected extensions.
# CLEANUP: CHECK
#
# Copyright (c) 2006-2007 Electric Cloud, Inc.
# All rights reserved
# -----------------------------------------------------------------------------

package silkperl;

# ----------------
#
# Includes
#
# ----------------
#use strict 'subs';
# clear out maptype since Silk Central server does not support SOAPStruct
use SOAP::Lite (  maptype => {} );  
#use SOAP::Lite ( +trace =>all, maptype => {} );  

# -------------------------------------------------------------------------
# Constants
# -------------------------------------------------------------------------
$SILK_TRUE       = "true";
$SILK_FALSE      = "false";

# -------------------------------------------------------------------------
# Globals
# -------------------------------------------------------------------------
$::gSILKPERLServer= "localhost";    # Silk Central server
$::gSILKPERLPass= "pass";           # Password for Silk Central server
$::gSILKPERLService= "sccsystem";   # Silk Central Web Service Name
$::gDebug = 2;
$::gSchema = "";
$::gUri = "";
$::gProxy = "";
$::gNoTimeStamps = 1;             # no time stamps for now
$::gTest;

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
sub Initialize($$$) {

    ($::gSILKPERLServer, $::gSILKPERLService, $::gDebug) = @_;
    #my ($Server, $User, $Pass, $Debug) = @_;

    $::gSchema = "http://" . $::gSILKPERLServer . 
        "/services/$::gSILKPERLService?WSDL";
    $::gUri = "http://borland.com/us/products/silk";

    # if protocol passed in, do not add one
    if (substr($::gSILKPERLServer,0,5) eq "http:" or
        substr($::gSILKPERLServer,0,4) eq "tcp:" or
        substr($::gSILKPERLServer,0,6) eq "https:") {
        $::gProxy = $::gSILKPERLServer .  "/services/$::gSILKPERLService";
    } else {
    $::gProxy = "http://" .
        $::gSILKPERLServer .  "/services/$::gSILKPERLService";
    }
    debugMsg(2, "Initialize server proxy=" . $::gProxy);

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

    my ($cmd, %argsin) = @_;

    my %ret = ();
    $ret {"value"} = "";
    $ret{"faultcode"} = 0;
    $ret{"faultstring"} = "";
    $ret{"faultdetail"} = "";

    debugMsg(99, "CallSilkCentral: $cmd");

    # find command in global command table
    if (!$::gCommands{$cmd}) {
        debugMsg(1, "Error: CallSilkCentral: unknown command $cmd");
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
            debugMsg(1, "Error: required arg $arg not found");
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
        debugMsg(99, "  $arg=$value");
    }

    # call SOAP
    my $result = SOAP_CALL($cmd, @soapargs);

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

    my ($methodName, @args ) = @_;

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

    if ($::gTest eq 1) {
        $soap->outputxml(1);
        $soap->readable(1);
    }

    # -------------------------------------------------
    # Prepare method name as SOAP::Data item
    # -------------------------------------------------
    my $method = SOAP::Data->name($methodName)
            ->attr({xmlns => $::gUri});

    # -------------------------------------------------
    # Make the call
    # -------------------------------------------------
    my $result = $soap->call($method => @args);

    if ($::gTest eq 1) {
      print "RESULT:" . $result . "\n";
    }

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


#### ---------------------------------------------------------------####
#### Helper Functions
#### ---------------------------------------------------------------####


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
    my ($errlev, $msg) = @_;
    
    my ($date, $time) = dateStrFormat(time());

    if ($::gNoTimeStamps) {
        if ($::gDebug >= $errlev) { print "$msg\n"; }
    } else {
        if ($::gDebug >= $errlev) { print "$date $time: $msg\n"; }
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
    my ($ref) = @_;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($ref);
    my $date = sprintf "%d-%02d-%02d", $year+1900, $mon+1, $mday;
    my $time = sprintf "%d:%02d:%02d", $hour, $min, $sec;
    return ($date,$time);
}

1;
