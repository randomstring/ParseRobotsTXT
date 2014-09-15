#!/usr/bin/env perl
#  -*- mode: perl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
#  vim:filetype=perl:et:sw=4:ts=4:sts=4
#  Copyright Blekko, Inc.

use strict;
use warnings;

use Test::More tests => 23;
use URI::XS;
use ParseRobotsTXT;
use Data::Dumper;

{
  no warnings 'once';
  $URI::XS::ABS_REMOTE_LEADING_DOTS = 1;
}

my $robotstxt;
my $rh = {};
my $ruri = URI::XS->new("http://www.example.com/robots.txt");
my $baseuri = URI::XS->new("http://www.example.com/");

my $line;
my $testname;
while($line = <DATA>) {
    $robotstxt = '';
    $testname = '';
    $rh = {};
    $robotstxt = $line if ($line !~ /^\#/);

    while ($line = <DATA>) {
        last if ($line =~ /^\#tests/);
        $robotstxt .= $line;
    }


    while ($line = <DATA>) {
        last if ($line =~ /^\#robots.txt/);
        chomp($line);
        next if ($line =~ /^\s*$/);
        my($agent, $result, $testname) = split (/\s+/,$line,3);
        $testname = $testname ? "$testname: " : "";

        $agent  = 'scoutjet' if ($agent eq '');
        $result = 2 if ($result =~ /^byname/i);
        $result = 1 if ($result =~ /^yes|all/i);
        $result = 0 if ($result =~ /^no/i);

        ParseRobotsTXT::set_agent($agent);
        $rh = ParseRobotsTXT::parse_robots($ruri,\$robotstxt);
        #    print Data::Dumper::Dumper($rh);
        my $banned = ParseRobotsTXT::banned($rh);
        unless ( is $banned, $result, "$testname$agent should be $result" ) {
            diag Data::Dumper::Dumper($rh);
        }
    }
}

__DATA__
#robots.txt
#tests
scoutjet no      empty file ok
#robots.txt
User-agent: *
Disallow: /
#tests
scoutjet yes     banned by *
#robots.txt
User-agent: *
Allow: /
Disallow: /foo/
#tests
scoutjet no      not banned by allow
other no
#robots.txt
User-agent: scoutjet
Disallow: /foo
User-agent: *
Disallow: /
#tests
scoutjet no      scoutjet disallowed on non-/
other yes
#robots.txt
User-agent: *
Disallow: /foo/
Allow: /
#tests
scoutjet no      disallow not /
#robots.txt
User-agent: Google
Disallow: /cgi-bin/

User-agent: *
Disallow: /
#tests
Google no          Google has specific disallow
scoutjet yes       Scoutjet is generic
other yes          other is generic too
#robots.txt
User-agent: Google
Disallow: /cgi-bin/

User-agent: *
Disallow: /
Disallow: /cgi-bin/
#tests
Google no          Google has specific disallow
scoutjet yes       Scoutjet is generic, two disallow lines
other yes          other is generic too
#robots.txt
User-agent: Google
Disallow: /cgi-bin/

User-agent: Scoutjet
Disallow: /
Disallow: /cgi-bin/

User-agent: *
Disallow: /
Disallow: /cgi-bin/
#tests
Google no          Google has specific disallow
scoutjet byname    Scoutjet is specific, two disallow lines
other yes          other is generic too
#robots.txt
User-agent: *      # comment #1
Disallow: /foo/    # comment 2
Disallow:          # this is a comment by me
#tests
scoutjet no        * does not have a disallow
#robots.txt
User-agent: other1
Disallow: /

User-agent: *
Disallow: /

User-agent: Google
Allow: /

User-agent: scoutjet
Disallow: /
#tests
scoutjet byname    scoutjet banned specifically
other1   byname    other1 banned specifically
other2   yes       other2 banned generically
Google   no
#robots.txt
User-agent: *
Disallow: /app/mobi
Disallow: /mobile

User-agent: Atomz/1.0
Allow: /jsps/core/lot/jsp/
Disallow: /

User-agent: Googlebot
Disallow:

User-agent: MSNBot
Disallow:

User-agent: Slurp
Disallow:

User-agent: Teoma
Disallow:

User-agent: Robozilla
Disallow:

User-agent: *
Disallow: /
Sitemap: http://www.sothebys.com/sitemap.xml
#tests
scoutjet yes      user agent * in two places, but all entries are 'disallow'
#robots.txt
User-agent: *
Disallow: /
Allow: /$
Allow: /robots.txt
Allow: /sitemap.xml
Allow: /calendar*
Allow: /contact
Allow: /faq
Allow: /jobs
Allow: /press
Allow: /team
#tests
scoutjet no      Disallow / rule but with Allow rules following
