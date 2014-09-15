#!/usr/bin/env perl
use URI::XS;
use ParseRobotsTXT;
use strict;
use Data::Dumper;

my $fn = shift;
my $verbose = 0;
if ($fn eq "-v") {
    $verbose = 1;
    $fn = shift;
}

$ParseRobotsTXT::KEEP_ALL_AGENT_RULES = 1;
$ParseRobotsTXT::verbose = $verbose;

usage ("need a file name of a robots.txt") if (! defined $fn || (! -f "$fn"));

my $robotstxt = '';
open(my $fh, '<', $fn) || usage("cannot open file [$fn] $!");
$robotstxt = join('',<$fh>);
close($fh);

my $robot_url = shift || "http://www.example.com/robots.txt";

my $robot_uri  = URI::XS->new($robot_url);
my $base_uri   = URI::XS->new("http://" . $robot_uri->host . "/");
my $robot_hash = ParseRobotsTXT::parse_robots($robot_uri,\$robotstxt);

print Data::Dumper::Dumper($robot_hash) if ($verbose);

if ($robot_hash->{error}) {
    print "====== robots.txt file contained ERRORS =====\n";
    foreach my $error (@{$robot_hash->{error}}) {
        print "ERROR: $error\n";
    }
}

my $path;
while ($path = <>) {
    chomp($path);
    my $base_uri   = URI::XS->new("http://" . $robot_uri->host . "/");
    my $agent = 'scoutjet';

    $path =~ s/\s+#.*//;
    if ($path =~ /^(\S+)\s+(\S+)/) {
        $path  = $1;
        $agent = $2;
    }

    my $uri   = URI::XS->new_abs($path,$base_uri);
    ParseRobotsTXT::set_agent($agent);

    my ($allow,$line,$rule,$rule_agent) = ParseRobotsTXT::allowed($robot_hash,$uri);

    print ($allow ? "ALLOW    " : "DISALLOW ");
    print "line=$line  rule=[$rule]  agent=[$rule_agent] ";
    print $uri . " agent=[$agent]\n";

}

sub usage
{
    my ($msg);
    print "ERROR: $msg\n" if ($msg);

    print "test_robots.pl  <robots.txt> [url]\n";
    print "  This takes a robot.txt file, parses it and then reads paths and an optional\n";
    print "  user agent,from standard in. Printing out whether or not the path would be\n";
    print "  ALLOWED or DISALLOWED by the robots.txt.\n";
    print "  example:\n";
    print "     test_robots.pl  /tmp/robots.txt.www.test.com  http://www.test.com/\n";

    exit(1);
}
