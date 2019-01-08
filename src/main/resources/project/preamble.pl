use ElectricCommander;
use File::Basename;
use ElectricCommander::PropDB;
use ElectricCommander::PropMod;

$|=1;

# Create ElectricCommander instance
my $ec = new ElectricCommander();
$ec->abortOnError(0);

my $cfgName = $opts->{configName};
print "Loading config $cfgName\n";

my $proj = "$[/myProject/projectName]";
my $cfg = new ElectricCommander::PropDB($ec,"/projects/$proj/silkCentral_cfgs");

if (!defined($cfg) || $cfg eq "") {
    print "Configuration [$cfgName] does not exist\n";
    exit 1;
}

# Add the option from the connection config
my %vals = $cfg->getRow($cfgName);
foreach my $c (keys %vals) {
    print "Adding config $c=$vals{$c}\n";
    $opts->{$c}=$vals{$c};
}


# Check that credential item exists
if (!defined $opts->{credential} || $opts->{credential} eq "") {
    print "Configuration [$cfgName] does not contain a SilkCentral credential\n";
    exit 1;
}
# Get user/password out of credential named in $opts->{credential}
my $xpath = $ec->getFullCredential("$opts->{credential}");
$opts->{silkCentral_user} = $xpath->findvalue("//userName");
$opts->{silkCentral_pass} = $xpath->findvalue("//password");

# Check for required items
if (!defined $opts->{silkCentral_url} || $opts->{silkCentral_url} eq "") {
    print "Configuration [$cfgName] does not contain a SilkCentral server name\n";
    exit 1;
}
if (!defined $opts->{silkCentral_user} || $opts->{silkCentral_user} eq "") {
    print "Credential [$opts->{credential}] does not contain a username\n";
    exit 1;
}
if (!defined $opts->{silkCentral_pass} || $opts->{silkCentral_pass} eq "") {
    print "Credential [$opts->{credential}] does not contain a password\n";
    exit 1;
}

$opts->{JobStepId} =  "$[/myJobStep/jobStepId]";

# Load the actual code into this process
if (!ElectricCommander::PropMod::loadPerlCodeFromProperty(
    $ec,"/myProject/silkCentral_driver/SilkCentral") ) {
    print "Could not load SilkCentral.pm\n";
    exit 1;
}

# Make an instance of the object, passing in options as a hash
my $gt = new SilkCentral($ec, $opts);


