#!/usr/bin/env perl
#  -*- mode: perl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
#  vim:filetype=perl:et:sw=4:ts=4:sts=4

use strict;
use warnings;

use Test::More;
use Test::Exception;

use URI::XS;
use ParseRobotsTXT;

use Data::Dumper;
use FindBin;
use File::Find::Rule;

use Perl6::Slurp;

# Get the test robots.txt file list.
my @robots_txt = File::Find::Rule->file('*.txt')
                                 ->in("$FindBin::Bin/robots_txt");

my %used;
unless (@robots_txt) {
    plan tests => 1;
    pass "No robots.txt files available yet";
}
else {
    @used{@robots_txt} = ();

    $ParseRobotsTXT::KEEP_ALL_AGENT_RULES = 1;
    $ParseRobotsTXT::verbose = my$verbose = $ENV{VERBOSE_ROBOTS};

    my @mappings;
    if (open my $mapping, "<", "$FindBin::Bin/robots_txt/mappings") {
        while(<$mapping>) {
            next if /\A#/;
            push @mappings, [ split /\s+/ ];
        }
    }
    plan tests => 7*(scalar @mappings) || 1;
    pass "No mappings, skipping test" unless @mappings;

    foreach my $mapping (@mappings) {
        my $robotstxt;

        # Each line from the mappings file will contain the following data,
        # some of it optional:
        #  - The file containing the robots.txt file itself (required)
        #  - The state (ALLOW or DENY) for the URL to be visited here
        #    (defaults to allow, but but be specified explicitly if you supply
        #    any of the items following)
        #  - The URL of the robots.txt file; defaults to
        #    "http://www.example.com/robots.txt" (but must be specified if you
        #    supply any of the items following)
        #  - The user-agent string to use (defaults to "scoutjet"; again,
        #    must be specified explicitly if site URL is supplied)
        #  - The site URL to be checked (defaults to the base URI)
        my($file, $state, $robot_url, $agent, $site_url) = @$mapping;

        $state     ||= 'ALLOW';
        $robot_url ||= 'http://www.example.com/robots.txt';
        $agent     ||= 'scoutjet';

        my $filepath = "$FindBin::Bin/robots_txt/$file";
        $used{$filepath}++;
        ok -e $filepath, "$file is there";
        ok -s _, "$file has data in it";

        lives_ok { $robotstxt = slurp($filepath) } "Can read $file";

        my $robot_uri = URI::XS->new($robot_url);
        my $base_uri   = URI::XS->new("http://" . $robot_uri->host . "/");

        $site_url ||= $base_uri;

        ok $robot_uri, "$robot_url mapped right";

        my $robot_hash =
            ParseRobotsTXT::parse_robots($robot_uri, \$robotstxt);
        ok $robot_hash, "parsed robots.txt";
        diag Dumper($robot_hash) if $verbose;

        my $site_uri = URI::XS->new_abs($site_url, $base_uri);
        ok $site_uri, "got a URI from new_abs";
        ParseRobotsTXT::set_agent($agent);

        my ($got_state, $got, $rule, $rule_agent) =
            ParseRobotsTXT::allowed($robot_hash, $site_uri);
        $got_state = {1 => 'ALLOW', 0 => 'DENY'}->{$got_state};
        is $state, $got_state, "$got_state correct for $site_uri";


        note "$got_state $file rule=[$rule] agent=[$rule_agent]";
    }
}

foreach my $file (keys %used) {
    next if $file =~ /mappings\Z/;
    diag "$file was not used in any test" unless defined $used{$file};
}

done_testing();
