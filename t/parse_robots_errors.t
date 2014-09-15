#
# test error and warning messages
#

use strict;
use warnings;

use Test::More qw(no_plan);
use URI::XS;
use ParseRobotsTXT;
use strict;
use Data::Dumper;

{
  no warnings 'once';
  $URI::XS::ABS_REMOTE_LEADING_DOTS = 1;
}
$ParseRobotsTXT::KEEP_ALL_AGENT_RULES = 1;

my $robotstxt;
my $rh = {};
my $ruri = URI::XS->new("http://www.example.com/robots.txt");
my $baseuri = URI::XS->new("http://www.example.com/");

my $line;
while($line = <DATA>) {
    $robotstxt = '';
    $rh = {};
    $robotstxt = $line if ($line !~ /^\#/);
    ParseRobotsTXT::set_agent("scoutjet");
    while ($line = <DATA>) {
        last if ($line =~ /^\#tests/);
        $robotstxt .= $line;
    }

    $rh = ParseRobotsTXT::parse_robots($ruri,\$robotstxt);

    # print Data::Dumper::Dumper($rh);

    while ($line = <DATA>) {
        last if ($line =~ /^\#robots.txt/);
        chomp($line);
        my $count = 0;

        if ($line =~ /^(.+)\s+(\d+)$/) {
            $line = $1;
            $count = $2;
        }
        next if ($line =~ /^\s*$/);
        next if ($line =~ /^#.*$/);

        my @errors = ((defined $rh && defined $rh->{error}) ? @{$rh->{error}} : () );

        if ($line =~ /^(none)$/) {
            my @errors = grep { ! /^warn/i } @errors;

            if (scalar(@errors) == 0) {
                ok(1);
            }
            else {
                ok(0);
                diag "found errors where there should be none.\n" . Data::Dumper::Dumper($rh);
            }
        }
        else {
            my @matches = grep { /$line/ } @errors;

            if ((scalar(@matches) == 0) || ($count && (scalar(@matches) != $count))) {
                ok(0);
                if ($count) {
                    diag "expected [$count] occurances of error message [$line]\n"  . Data::Dumper::Dumper($rh);
                }
                else {
                    diag "expected error message [$line]\n"  . Data::Dumper::Dumper($rh);
                }
            }
            else {
                ok(1);
            }
        }
    }
}


#
# Test data format:
#
# #robots.txt
# <robots.txt>
# #tests
# "none" | (<error string> [<num occurances>])*
#

__DATA__
#robots.txt
#tests
none
#robots.txt
User-agent: *
Disallow: /

User-agent: Scoutjet
Disallow: /
#tests
none
#robots.txt
User-agent: *
Allow: /

Disallow: /foo/
Allow: /foo/bar
#tests
disallow was preceeded by a blank line 1
#robots.txt
User-agent: *
Bogus: 1
Crawl-Before: 0800
Crawl-After:  0900
Disallow: /uuuuuuu/xx/
Allow: /*/xx/yyy/
#tests
Ignoring unsupported extention 3
#robots.txt
er-agent: WebmasterWorldForumBot
Disallow: /

User-agent: URL_Spider_Pro
Disallow: /

User-agent: CherryPicker
Disallow: /

Allow: /foo
#tests
Ignoring unsupported extention 1
missing preceeding useragent declaration 1
was preceeded by a blank line 1
#robots.txt
# customs.gov/robots.txt
User-agent: gsa-crawler
Allow: /

User-agent: googlebot
Allow: /
Request-rate: 1/5
Visit-time: 0400-1100

User-agent: slurp
Allow: /
Request-rate: 1/5
Visit-time: 0400-1100

User-agent: msnbot
Allow: /
Request-rate: 1/5
Visit-time: 0400-1100

User-agent: bingbot
Allow: /
Request-rate: 1/5
Visit-time: 0400-1100
User-agent: *

Disallow: /

#tests
Ignoring unsupported extention 8
was preceeded by a blank line, not RFC complient 1
