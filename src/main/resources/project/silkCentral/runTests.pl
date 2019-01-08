##########################
# runTests.pl
##########################
my $opts;

$opts->{configName} = "$[configName]";
$opts->{testExecutionId} = q{$[testExecutionId]};
$opts->{version} = q{$[version]};
$opts->{build} = q{$[build]};
$opts->{resource} = q{$[resource]};
$opts->{timeLimit} = q{$[timeLimit]};
$opts->{runParallel} = q{$[runParallel]};

$[/myProject/procedure_helpers/preamble]


$gt->runSilkTest();
exit($opts->{exitcode});
